import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

/// Resolves public Facebook video links by requesting the mobile-site
/// version of the page (`m.facebook.com`), which historically embeds plain
/// `hd_src` / `sd_src` fields with direct MP4 URLs in the HTML — unlike the
/// desktop site, no JS execution is needed to reach them.
///
/// LIMITATIONS: only public videos; Facebook changes markup periodically,
/// so the regexes below are the part to revisit if this stops working.
class FacebookResolver implements LinkResolver {
  final Dio _dio;
  FacebookResolver({Dio? dio}) : _dio = dio ?? Dio();

  static final _urlPattern = RegExp(
    r'(facebook\.com|fb\.watch)\/',
    caseSensitive: false,
  );

  static final _hdPattern = RegExp(r'"playable_url_quality_hd":"([^"]+)"');
  static final _sdPattern = RegExp(r'"playable_url":"([^"]+)"');
  static final _titlePattern = RegExp(r'<title>([^<]+)<\/title>');

  @override
  String get name => 'Facebook';

  @override
  bool canHandle(String url) => _urlPattern.hasMatch(url);

  String _toMobileUrl(String url) {
    return url
        .replaceFirst('www.facebook.com', 'm.facebook.com')
        .replaceFirst('facebook.com', 'm.facebook.com');
  }

  String _unescape(String raw) => raw.replaceAll(r'\/', '/').replaceAll(r'%', '%');

  @override
  Future<MediaMetadata> analyze(String url) async {
    try {
      final mobileUrl = _toMobileUrl(url);
      final response = await _dio.get<String>(
        mobileUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          },
          responseType: ResponseType.plain,
        ),
      );

      final body = response.data ?? '';
      final hdMatch = _hdPattern.firstMatch(body);
      final sdMatch = _sdPattern.firstMatch(body);
      final titleMatch = _titlePattern.firstMatch(body);

      final hdUrl = hdMatch != null ? _unescape(hdMatch.group(1)!) : null;
      final sdUrl = sdMatch != null ? _unescape(sdMatch.group(1)!) : null;

      if (hdUrl == null && sdUrl == null) {
        throw ResolverException(
          'Could not find a downloadable video on this page. It may be '
          'private, or Facebook may have changed its page structure.',
        );
      }

      final variants = <MediaVariant>[];
      if (hdUrl != null) {
        variants.add(MediaVariant(
          id: 'fb_hd',
          type: MediaType.video,
          label: 'HD',
          container: 'mp4',
          streamUrl: hdUrl,
        ));
      }
      if (sdUrl != null) {
        variants.add(MediaVariant(
          id: 'fb_sd',
          type: MediaType.video,
          label: 'SD',
          container: 'mp4',
          streamUrl: sdUrl,
        ));
      }
      final bestUrl = hdUrl ?? sdUrl!;
      variants.add(MediaVariant(
        id: 'fb_audio',
        type: MediaType.audio,
        label: 'Audio only',
        container: 'm4a',
        streamUrl: bestUrl,
      ));

      return MediaMetadata(
        title: titleMatch?.group(1)?.trim() ?? 'Facebook video',
        thumbnailUrl: null,
        duration: Duration.zero,
        source: MediaSource.facebook,
        sourceUrl: url,
        variants: variants,
      );
    } on ResolverException {
      rethrow;
    } catch (e) {
      throw ResolverException(
        'Could not analyze this Facebook link. It may be private or '
        'Facebook may have changed something the resolver needs updating for.',
        e,
      );
    }
  }
}
