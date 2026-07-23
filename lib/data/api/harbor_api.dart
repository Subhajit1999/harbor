import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/media_variant.dart';

const _tag = 'HarborApi';

class ApiException implements Exception {
  final String message;
  final Object? cause;
  ApiException(this.message, [this.cause]);

  @override
  String toString() => 'ApiException: $message';
}

class HarborApi {
  final Dio _dio;

  HarborApi({
    Dio? dio,
  }) : _dio = dio ?? Dio();

  String get _baseUrl => dotenv.env['RESOLVER_SERVER_URL'] ?? '';
  String get _apiKey => dotenv.env['RESOLVER_API_KEY'] ?? '';

  static final _urlPattern = RegExp(
    r'(youtube\.com|youtu\.be|instagram\.com|facebook\.com|fb\.watch)',
    caseSensitive: false,
  );

  bool isSupported(String url) => _urlPattern.hasMatch(url);

  Future<MediaMetadata> analyze(String url) async {
    var base = _baseUrl.trim();
    if (base.isEmpty) {
      throw ApiException('Server URL is not configured. Please set it in Settings.');
    }
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final endpoint = '$base/resolve';
    final body = {'url': url};
    AppLogger.i(_tag, 'URL: $endpoint\nBODY: ${jsonEncode(body)}');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: body,
        options: Options(
          headers: {'X-API-Key': _apiKey},
          contentType: 'application/json',
        ),
      );

      final data = response.data!;
      AppLogger.i(
        _tag,
        'URL: $endpoint\nSTATUS CODE: ${response.statusCode}\nRESPONSE: ${jsonEncode(data)}',
      );

      final variants = (data['variants'] as List)
          .cast<Map<String, dynamic>>()
          .map(_variantFromJson)
          .toList();

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
        'URL: $endpoint\nBODY: ${jsonEncode(body)}\n'
        'STATUS CODE: ${e.response?.statusCode}\nRESPONSE: ${e.response?.data}',
        e,
        st,
      );
      throw ApiException(
        detail as String? ??
            'Could not reach the server. Check its URL/API key in '
                'Settings, or that it\'s not asleep (free hosting tiers spin '
                'down when idle).',
        e,
      );
    } catch (e, st) {
      AppLogger.e(_tag, 'URL: $endpoint\nBODY: ${jsonEncode(body)}\nUnexpected error', e, st);
      throw ApiException('Could not analyze this link via the server.', e);
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
