import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/media_variant.dart';
import '../../domain/repositories/link_resolver.dart';

const _tag = 'YtDlpResolver';

/// Resolves links via a self-hosted backend (see `backend/`) that wraps
/// yt-dlp — noticeably more robust than the app's built-in scrapers
/// (`instagram_resolver.dart`, `facebook_resolver.dart`,
/// `youtube_resolver.dart`), at the cost of depending on a server the user
/// runs themselves. Opt-in: only registered by [ResolverRegistry] when a
/// resolver server URL is baked in at build time (`--dart-define-from-file=.env`
/// — see `lib/core/constants/env.dart`) — see that class for the fallback
/// behavior when it's not.
///
/// The backend's `/resolve` response is shaped to match [MediaVariant]'s
/// fields 1:1 (see backend/app.py and backend/README.md), so this class is
/// deliberately thin — just the HTTP call and JSON→entity mapping.
class YtDlpResolver implements LinkResolver {
  final String baseUrl;
  final String apiKey;
  final Dio _dio;

  YtDlpResolver({
    required this.baseUrl,
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  static final _urlPattern = RegExp(
    r'(youtube\.com|youtu\.be|instagram\.com|facebook\.com|fb\.watch)',
    caseSensitive: false,
  );

  @override
  String get name => 'yt-dlp';

  @override
  bool canHandle(String url) => _urlPattern.hasMatch(url);

  @override
  Future<MediaMetadata> analyze(String url) async {
    AppLogger.i(_tag, 'POST $baseUrl/resolve for $url');
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/resolve',
        data: {'url': url},
        options: Options(
          headers: {'X-API-Key': apiKey},
          contentType: 'application/json',
        ),
      );

      final data = response.data!;
      final variants = (data['variants'] as List)
          .cast<Map<String, dynamic>>()
          .map(_variantFromJson)
          .toList();
      AppLogger.i(
        _tag,
        '$baseUrl/resolve -> ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms, '
        '${variants.length} variant(s)',
      );

      return MediaMetadata(
        title: data['title'] as String? ?? 'Untitled',
        thumbnailUrl: data['thumbnailUrl'] as String?,
        duration: Duration(seconds: (data['durationSeconds'] as num?)?.toInt() ?? 0),
        source: _sourceFromString(data['source'] as String?),
        sourceUrl: url,
        variants: variants,
      );
    } on DioException catch (e, st) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      AppLogger.e(
        _tag,
        '$baseUrl/resolve failed after ${stopwatch.elapsedMilliseconds}ms: '
        '${e.response?.statusCode} ${detail ?? e.message}',
        e,
        st,
      );
      throw ResolverException(
        detail as String? ??
            'Could not reach the resolver server. Check its URL/API key in '
                'Settings, or that it\'s not asleep (free hosting tiers spin '
                'down when idle).',
        e,
      );
    } catch (e, st) {
      AppLogger.e(_tag, 'Unexpected error calling $baseUrl/resolve', e, st);
      throw ResolverException('Could not analyze this link via the resolver server.', e);
    }
  }

  MediaVariant _variantFromJson(Map<String, dynamic> json) {
    return MediaVariant(
      id: json['id'] as String,
      type: (json['type'] as String) == 'video' ? MediaType.video : MediaType.audio,
      label: json['label'] as String,
      container: json['container'] as String,
      codec: json['codec'] as String?,
      bitrateKbps: (json['bitrateKbps'] as num?)?.toInt(),
      estimatedSizeBytes: (json['estimatedSizeBytes'] as num?)?.toInt(),
      streamUrl: json['streamUrl'] as String,
      audioStreamUrl: json['audioStreamUrl'] as String?,
      requiresMuxing: json['requiresMuxing'] as bool? ?? false,
      needsAudioExtraction: json['needsAudioExtraction'] as bool? ?? false,
    );
  }

  MediaSource _sourceFromString(String? raw) {
    switch (raw) {
      case 'youtube':
        return MediaSource.youtube;
      case 'instagram':
        return MediaSource.instagram;
      case 'facebook':
        return MediaSource.facebook;
      default:
        return MediaSource.unknown;
    }
  }
}
