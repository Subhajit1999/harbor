import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

const _tag = 'InstagramResolver';

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
      AppLogger.d(
        _tag,
        'GET $url -> ${response.statusCode}, ${html.length} bytes of HTML',
      );
      final document = html_parser.parse(html);

      String? metaContent(String property) {
        final tag = document.querySelector('meta[property="$property"]');
        return tag?.attributes['content'];
      }

      // Logged as a chain (not just the final result) so a misclassification
      // like "photo post" is diagnosable from the log alone — which
      // strategies were tried and that all of them came back empty, rather
      // than just the final null forcing a guess at why.
      String? videoUrl;
      String usedStrategy = 'none';
      for (final entry in <String, String? Function()>{
        'og:video': () => metaContent('og:video'),
        'og:video:secure_url': () => metaContent('og:video:secure_url'),
        'og:video:url': () => metaContent('og:video:url'),
        'ld+json': () => _videoUrlFromLdJson(document),
        'raw-html-regex': () => _videoUrlFromRawHtml(html),
      }.entries) {
        final result = entry.value();
        if (result != null) {
          videoUrl = result;
          usedStrategy = entry.key;
          break;
        }
      }
      final imageUrl = metaContent('og:image');
      final title = metaContent('og:title') ?? 'Instagram post';
      AppLogger.i(
        _tag,
        'video URL: ${videoUrl != null ? 'found via $usedStrategy' : 'NOT FOUND (tried all strategies)'}, '
        'thumbnail: ${imageUrl != null}',
      );

      // Harbor only downloads video/audio (see MediaVariant/MediaType — there
      // is no image variant type), so a post with no extractable video URL
      // is a failure for our purposes even if a thumbnail image was found.
      // The previous guard only threw when *both* were missing, which let a
      // photo-only post (or a Reel where every video-URL strategy missed)
      // through as a "successful" analyze() with an empty `variants` list —
      // the Analysis screen then rendered title/thumbnail/duration with
      // nothing below them and no error, which looked like a silent bug
      // rather than the expected "can't download this" case.
      if (videoUrl == null) {
        throw ResolverException(
          imageUrl != null
              ? 'This looks like a photo post — Harbor only downloads video '
                  'and audio, not images.'
              : 'Could not find downloadable media on this page. The post '
                  'may be private, or Instagram may have changed its page '
                  'structure.',
        );
      }

      final variants = <MediaVariant>[
        MediaVariant(
          id: 'ig_video',
          type: MediaType.video,
          label: 'Original',
          container: 'mp4',
          streamUrl: videoUrl,
        ),
        MediaVariant(
          id: 'ig_audio',
          type: MediaType.audio,
          label: 'Audio only',
          container: 'm4a',
          // Instagram doesn't expose a separate audio-only CDN URL — this
          // points at the same video file, and DownloadManager strips the
          // audio track out natively (see MediaVariant.needsAudioExtraction).
          streamUrl: videoUrl,
          needsAudioExtraction: true,
        ),
      ];

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
    } catch (e, st) {
      AppLogger.e(_tag, 'Unexpected error analyzing $url', e, st);
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
