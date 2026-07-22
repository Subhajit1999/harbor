import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// One downloadable option surfaced by a [LinkResolver] for a given source
/// URL — e.g. "1080p MP4 (H.264)" or "AAC 128kbps". Purely a data holder;
/// resolvers are the only place that knows how to turn this into bytes.
class MediaVariant extends Equatable {
  final String id;
  final MediaType type;
  final String label; // e.g. "1080p", "128 kbps"
  final String container; // e.g. "mp4", "m4a"
  final String? codec;
  final int? bitrateKbps;
  final int? estimatedSizeBytes;
  final String streamUrl;
  final String? audioStreamUrl; // populated when video-only + separate audio
  final bool requiresMuxing;

  // Set when `streamUrl` actually points at a full audio+video file (some
  // sources — Instagram, Facebook — don't expose a separate audio-only CDN
  // URL the way YouTube does) and this variant's `type` is
  // [MediaType.audio] anyway: the downloaded file needs its audio track
  // stripped out natively before it's a real standalone audio file.
  // Mutually exclusive with [requiresMuxing]/[audioStreamUrl] — this is the
  // "one input, keep only audio" case, not the "two inputs, combine" case.
  final bool needsAudioExtraction;

  const MediaVariant({
    required this.id,
    required this.type,
    required this.label,
    required this.container,
    this.codec,
    this.bitrateKbps,
    this.estimatedSizeBytes,
    required this.streamUrl,
    this.audioStreamUrl,
    this.requiresMuxing = false,
    this.needsAudioExtraction = false,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        label,
        container,
        codec,
        bitrateKbps,
        estimatedSizeBytes,
        streamUrl,
        audioStreamUrl,
        requiresMuxing,
        needsAudioExtraction,
      ];
}

/// Metadata about the source content, shown on the Analysis screen before
/// the user picks a variant.
class MediaMetadata extends Equatable {
  final String title;
  final String? thumbnailUrl;
  final Duration duration;
  final MediaSource source;
  final String sourceUrl;
  final List<MediaVariant> variants;

  const MediaMetadata({
    required this.title,
    this.thumbnailUrl,
    required this.duration,
    required this.source,
    required this.sourceUrl,
    required this.variants,
  });

  List<MediaVariant> get videoVariants =>
      variants.where((v) => v.type == MediaType.video).toList();

  List<MediaVariant> get audioVariants =>
      variants.where((v) => v.type == MediaType.audio).toList();

  @override
  List<Object?> get props => [title, thumbnailUrl, duration, source, sourceUrl, variants];
}
