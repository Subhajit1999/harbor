import '../entities/media_variant.dart';

/// Contract a link resolver implements. Currently one implementation
/// (`YtDlpResolver`, calling the backend's `/resolve`) handles every source
/// — nothing outside it knows or cares how a given platform is analyzed.
/// The rest of the app (Import screen, Analysis screen, Download manager)
/// only ever talks to this interface, so a future second implementation
/// (a different backend, an on-device fallback, etc.) is a matter of
/// writing one new class and registering it in `ResolverRegistry` —
/// nothing else changes.
abstract class LinkResolver {
  /// Human-readable name, e.g. "YouTube". Shown in the UI (source badge).
  String get name;

  /// Returns true if this resolver knows how to handle [url].
  /// Should be a cheap, synchronous check (regex/host match) — no network.
  bool canHandle(String url);

  /// Fetches title/thumbnail/duration and the list of downloadable variants
  /// for [url]. Throws [ResolverException] on failure (private/unavailable
  /// content, network error, or the source changed its internal API and the
  /// resolver needs updating).
  Future<MediaMetadata> analyze(String url);
}

class ResolverException implements Exception {
  final String message;
  final Object? cause;
  ResolverException(this.message, [this.cause]);

  @override
  String toString() => 'ResolverException: $message';
}
