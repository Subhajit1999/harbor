import '../../core/constants/env.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/repositories/link_resolver.dart';
import 'ytdlp_resolver.dart';

const _tag = 'ResolverRegistry';

/// Single place the app asks "who can handle this URL". The app has no
/// on-device link analysis of its own — every source (YouTube, Instagram,
/// Facebook) goes through [YtDlpResolver], which calls the backend's
/// `/resolve` endpoint (see `backend/app.py`). There used to be per-source
/// Dart scrapers here (og:video meta tags, JSON-LD, regex-on-HTML); they
/// were a maintenance burden every time a platform changed its markup, and
/// the backend is strictly more capable (real yt-dlp, not a reimplementation
/// of a slice of it) — so they're gone, not "kept as a fallback."
///
/// This means the resolver server URL/API key (see [Env] —
/// `--dart-define-from-file=.env`) are no longer optional: without them,
/// nothing here can resolve anything. That's a deliberate tradeoff, not an
/// oversight — logged loudly at construction so a missing `.env` is obvious
/// immediately instead of surfacing as a confusing runtime failure.
class ResolverRegistry {
  final List<LinkResolver> _resolvers;

  ResolverRegistry({List<LinkResolver>? resolvers})
      : _resolvers = resolvers ??
            [
              YtDlpResolver(
                baseUrl: Env.resolverServerUrl,
                apiKey: Env.resolverApiKey,
              ),
            ] {
    if (Env.resolverServerUrl.isEmpty) {
      AppLogger.e(
        _tag,
        'No resolver server URL baked in (missing --dart-define-from-file=.env at build time) — '
        'every analyze() will fail. This is not optional anymore; there is no built-in scraper fallback.',
      );
    } else {
      AppLogger.i(_tag, 'Resolver: ${_resolvers.map((r) => r.name).join(', ')} @ ${Env.resolverServerUrl}');
    }
  }

  LinkResolver? resolverFor(String url) {
    for (final resolver in _resolvers) {
      if (resolver.canHandle(url)) {
        AppLogger.d(_tag, 'resolverFor("$url") -> ${resolver.name}');
        return resolver;
      }
    }
    AppLogger.w(_tag, 'resolverFor("$url") -> no resolver matched');
    return null;
  }

  bool isSupported(String url) => resolverFor(url) != null;
}
