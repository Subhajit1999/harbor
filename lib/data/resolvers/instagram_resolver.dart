import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

/// Resolves public Instagram post/reel links by requesting the post page
/// and reading the video URL Instagram embeds in the server-rendered HTML
/// for public content. Reels frequently omit the `og:video` meta tag that
/// posts/IGTV reliably include, so this tries several extraction
/// strategies in order of reliability before giving up.
///
/// LIMITATIONS (real, not hypothetical):
/// - Only works for public posts. Private accounts and most Stories require
///   an authenticated session (your own logged-in cookies), which isn't
///   implemented here.
/// - Instagram periodically changes what it server-renders vs. loads via JS;
///   if none of the strategies below find a video URL anymore, this is the
///   single place that needs a new one added. Treat this class as the spot
///   that absorbs that churn.
class InstagramResolver implements LinkResolver {
  final Dio _dio;
  InstagramResolver({Dio? dio}) : _dio = dio ?? Dio();

  static final _urlPattern = RegExp(
    r'instagram\.com\/(p|reel|tv)\/',
    caseSensitive: false,
  );

  @override
  String get name => 'Instagram';

  @override
  bool canHandle(String url) => _urlPattern.hasMatch(url);

  @override
  Future<MediaMetadata> analyze(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            // A standard mobile UA renders more of the page server-side
            // than a bare HTTP client's default UA does.
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          },
          responseType: ResponseType.plain,
        ),
      );

      final html = response.data ?? '';
      final document = html_parser.parse(html);

      String? metaContent(String property) {
        final tag = document.querySelector('meta[property="$property"]');
        return tag?.attributes['content'];
      }

      final videoUrl = metaContent('og:video') ??
          metaContent('og:video:secure_url') ??
          metaContent('og:video:url') ??
          _videoUrlFromLdJson(document) ??
          _videoUrlFromRawHtml(html);
      final imageUrl = metaContent('og:image');
      final title = metaContent('og:title') ?? 'Instagram post';

      if (videoUrl == null && imageUrl == null) {
        throw ResolverException(
          'Could not find downloadable media on this page. The post may be '
          'private, or Instagram may have changed its page structure.',
        );
      }

      final variants = <MediaVariant>[];
      if (videoUrl != null) {
        variants.add(MediaVariant(
          id: 'ig_video',
          type: MediaType.video,
          label: 'Original',
          container: 'mp4',
          streamUrl: videoUrl,
        ));
        variants.add(MediaVariant(
          id: 'ig_audio',
          type: MediaType.audio,
          label: 'Audio only',
          container: 'm4a',
          // Instagram doesn't expose a separate audio-only CDN URL — this
          // points at the same video file, and DownloadManager strips the
          // audio track out natively (see MediaVariant.needsAudioExtraction).
          streamUrl: videoUrl,
          needsAudioExtraction: true,
        ));
      }

      return MediaMetadata(
        title: title,
        thumbnailUrl: imageUrl,
        duration: Duration.zero, // not reliably available from meta tags
        source: MediaSource.instagram,
        sourceUrl: url,
        variants: variants,
      );
    } on ResolverException {
      rethrow;
    } catch (e) {
      throw ResolverException(
        'Could not analyze this Instagram link. It may be private or '
        'Instagram may have changed something the resolver needs updating for.',
        e,
      );
    }
  }

  /// Instagram frequently embeds a schema.org `VideoObject` in a
  /// `<script type="application/ld+json">` tag even when `og:video` is
  /// missing (common for Reels) — its `contentUrl` is the direct video URL.
  String? _videoUrlFromLdJson(Document document) {
    for (final script in document.querySelectorAll('script[type="application/ld+json"]')) {
      final text = script.text.trim();
      if (text.isEmpty) continue;
      try {
        final decoded = jsonDecode(text);
        final candidates = decoded is List ? decoded : [decoded];
        for (final entry in candidates) {
          if (entry is! Map) continue;
          final direct = entry['contentUrl'];
          if (direct is String && direct.isNotEmpty) return direct;
          final video = entry['video'];
          if (video is Map && video['contentUrl'] is String) {
            return video['contentUrl'] as String;
          }
        }
      } catch (_) {
        // Not valid/relevant JSON — try the next script tag.
      }
    }
    return null;
  }

  /// Last-resort fallback: Instagram's inline page-state JSON (not exposed
  /// as a clean `<script type="application/json">` block) still contains a
  /// `"video_url":"..."` field with the URL JSON-escaped — forward slashes
  /// as `\/` and ampersands as the unicode escape for `&` — grab it
  /// directly out of the raw HTML with a regex.
  String? _videoUrlFromRawHtml(String html) {
    final match = RegExp(r'"video_url":"([^"]+)"').firstMatch(html);
    if (match == null) return null;
    const ampersandEscape = '\\u0026';
    return match.group(1)!.replaceAll(r'\/', '/').replaceAll(ampersandEscape, '&');
  }
}
