import '../../domain/repositories/link_resolver.dart';
import 'facebook_resolver.dart';
import 'instagram_resolver.dart';
import 'youtube_resolver.dart';

/// Single place the app asks "who can handle this URL". Adding a new source
/// later means writing one [LinkResolver] implementation and adding it to
/// [_resolvers] — nothing else in the app needs to change.
class ResolverRegistry {
  final List<LinkResolver> _resolvers;

  ResolverRegistry({List<LinkResolver>? resolvers})
      : _resolvers = resolvers ??
            [
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
