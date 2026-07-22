/// Compile-time defaults from the repo-root `.env` (see `.env.example`).
/// These are baked in at build time via `--dart-define-from-file=.env` —
/// Flutter's native mechanism, no extra package needed. Run/build with:
///
///   flutter run --dart-define-from-file=.env
///
/// Without that flag these are just empty strings, same as if no defaults
/// existed at all — [SettingsService] falls back to them only when the
/// user hasn't set an override in Settings -> Advanced, so the app still
/// works with neither in place.
class Env {
  Env._();

  static const String resolverServerUrl = String.fromEnvironment('RESOLVER_SERVER_URL');
  static const String resolverApiKey = String.fromEnvironment('RESOLVER_API_KEY');
}
