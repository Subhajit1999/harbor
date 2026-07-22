import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

/// Resolves public Instagram post/reel links by requesting the post page
/// and reading the `og:video` / `og:image` meta tags Instagram embeds in
/// the server-rendered HTML for public content.
///
/// LIMITATIONS (real, not hypothetical):
/// - Only works for public posts. Private accounts and most Stories require
///   an authenticated session (your own logged-in cookies), which isn't
///   implemented here.
/// - Instagram periodically changes what it server-renders vs. loads via JS;
///   if `og:video` stops appearing, this resolver needs the parsing
///   strategy updated (e.g. to read the `__additionalDataLoaded` JSON blob
///   instead). Treat this class as the single place that absorbs that churn.
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

      final document = html_parser.parse(response.data ?? '');

      String? metaContent(String property) {
        final tag = document.querySelector('meta[property="$property"]');
        return tag?.attributes['content'];
      }

      final videoUrl = metaContent('og:video');
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
          streamUrl: videoUrl, // extracted client-side after download
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
}
