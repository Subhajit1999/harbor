import '../../core/constants/env.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/repositories/link_resolver.dart';
import 'facebook_resolver.dart';
import 'instagram_resolver.dart';
import 'youtube_resolver.dart';
import 'ytdlp_resolver.dart';

const _tag = 'ResolverRegistry';

/// Single place the app asks "who can handle this URL". Adding a new source
/// later means writing one [LinkResolver] implementation and adding it to
/// [_resolvers] — nothing else in the app needs to change.
class ResolverRegistry {
  final List<LinkResolver> _resolvers;

  /// If a resolver server URL is baked in at build time (see [Env] —
  /// `--dart-define-from-file=.env`), [YtDlpResolver] is tried first (more
  /// robust than the built-in scrapers) — the pure-Dart resolvers stay
  /// registered after it as the always-available fallback for URLs it
  /// doesn't cover, or for when no server is configured at all (the
  /// default: the app works standalone, no server required).
  ResolverRegistry({List<LinkResolver>? resolvers})
      : _resolvers = resolvers ??
            [
              if (Env.resolverServerUrl.isNotEmpty)
                YtDlpResolver(
                  baseUrl: Env.resolverServerUrl,
                  apiKey: Env.resolverApiKey,
                ),
              YoutubeResolver(),
              InstagramResolver(),
              FacebookResolver(),
            ] {
    // Logged once at construction, not per-lookup — this is exactly the
    // line that would have made the "app falls back to the built-in
    // scraper because .env wasn't baked in" bug obvious immediately
    // instead of needing a binary-string grep to diagnose.
    AppLogger.i(
      _tag,
      'Registered resolvers (in priority order): '
      '${_resolvers.map((r) => r.name).join(' -> ')}'
      '${Env.resolverServerUrl.isEmpty ? ' (no resolver server URL baked in — using built-in scrapers only)' : ''}',
    );
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
