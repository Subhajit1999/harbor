import '../../core/constants/env.dart';
import '../../domain/repositories/link_resolver.dart';
import 'facebook_resolver.dart';
import 'instagram_resolver.dart';
import 'youtube_resolver.dart';
import 'ytdlp_resolver.dart';

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
            ];

  LinkResolver? resolverFor(String url) {
    for (final resolver in _resolvers) {
      if (resolver.canHandle(url)) return resolver;
    }
    return null;
  }

  bool isSupported(String url) => resolverFor(url) != null;
}
