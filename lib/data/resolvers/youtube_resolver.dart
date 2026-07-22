import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

/// Resolves YouTube links entirely on-device via `youtube_explode_dart`,
/// which reimplements the same internal player-API + signature-cipher
/// approach YouTube's own apps and yt-dlp use — no server, no API key.
///
/// IMPORTANT (read before touching this file): YouTube changes its player
/// internals periodically, which can break stream resolution here. When
/// that happens the fix is almost always an upgrade of the
/// `youtube_explode_dart` dependency, not a change to this class. Do not
/// attempt to hand-roll cipher decryption here — that logic belongs in the
/// upstream package where the community keeps it current.
class YoutubeResolver implements LinkResolver {
  final yt.YoutubeExplode _client;
  YoutubeResolver({yt.YoutubeExplode? client}) : _client = client ?? yt.YoutubeExplode();

  static final _urlPattern = RegExp(
    r'(youtube\.com\/(watch\?v=|shorts\/)|youtu\.be\/)',
    caseSensitive: false,
  );

  @override
  String get name => 'YouTube';

  @override
  bool canHandle(String url) => _urlPattern.hasMatch(url);

  @override
  Future<MediaMetadata> analyze(String url) async {
    try {
      final video = await _client.videos.get(url);
      final manifest = await _client.videos.streamsClient.getManifest(video.id);

      final variants = <MediaVariant>[];

      // Muxed (video+audio combined) streams — simplest to download, but
      // capped at 720p by YouTube's own design for muxed formats.
      for (final s in manifest.muxed.sortByVideoQuality()) {
        variants.add(MediaVariant(
          id: 'muxed_${s.tag}',
          type: MediaType.video,
          label: s.qualityLabel,
          container: s.container.name,
          codec: s.videoCodec,
          bitrateKbps: (s.bitrate.bitsPerSecond / 1000).round(),
          estimatedSizeBytes: s.size.totalBytes,
          streamUrl: s.url.toString(),
          requiresMuxing: false,
        ));
      }

      // Adaptive video-only streams (1080p+) — need the best audio track
      // muxed in after download.
      final bestAudio = manifest.audioOnly.withHighestBitrate();
      for (final s in manifest.videoOnly.sortByVideoQuality()) {
        variants.add(MediaVariant(
          id: 'video_${s.tag}',
          type: MediaType.video,
          label: s.qualityLabel,
          container: s.container.name,
          codec: s.videoCodec,
          bitrateKbps: (s.bitrate.bitsPerSecond / 1000).round(),
          estimatedSizeBytes: s.size.totalBytes + bestAudio.size.totalBytes,
          streamUrl: s.url.toString(),
          audioStreamUrl: bestAudio.url.toString(),
          requiresMuxing: true,
        ));
      }

      // Audio-only streams.
      for (final s in manifest.audioOnly.sortByBitrate()) {
        variants.add(MediaVariant(
          id: 'audio_${s.tag}',
          type: MediaType.audio,
          label: '${(s.bitrate.bitsPerSecond / 1000).round()} kbps',
          container: s.container.name,
          codec: s.audioCodec,
          bitrateKbps: (s.bitrate.bitsPerSecond / 1000).round(),
          estimatedSizeBytes: s.size.totalBytes,
          streamUrl: s.url.toString(),
        ));
      }

      return MediaMetadata(
        title: video.title,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration ?? Duration.zero,
        source: MediaSource.youtube,
        sourceUrl: url,
        variants: variants,
      );
    } catch (e) {
      throw ResolverException(
        'Could not analyze this YouTube link. It may be private, age-restricted, '
        'region-locked, or YouTube may have changed something the resolver '
        'needs updating for.',
        e,
      );
    }
  }

  void dispose() => _client.close();
}
