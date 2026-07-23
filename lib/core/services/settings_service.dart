import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/env.dart';

/// Thin typed wrapper over SharedPreferences for the handful of user
/// preferences Harbor has (Settings screen). Deliberately not using Isar for
/// this — these are simple scalar values, not queryable records, so a
/// second storage engine would be overkill.
class SettingsService {
  late final SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();
  static const _secureResolverApiKeyKey = 'settings.resolverApiKey.secure';
  String? _cachedResolverApiKey;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedResolverApiKey = await _secureStorage.read(key: _secureResolverApiKeyKey);
    // One-time migration: this used to live in plaintext SharedPreferences.
    // Move any existing value into Keychain/Keystore, then drop the plaintext copy.
    if (_cachedResolverApiKey == null) {
      final legacy = _prefs.getString(AppConstants.prefResolverApiKey);
      if (legacy != null && legacy.isNotEmpty) {
        _cachedResolverApiKey = legacy;
        await _secureStorage.write(key: _secureResolverApiKeyKey, value: legacy);
        await _prefs.remove(AppConstants.prefResolverApiKey);
      }
    }
  }

  bool get wifiOnly => _prefs.getBool(AppConstants.prefWifiOnly) ?? false;
  set wifiOnly(bool value) => _prefs.setBool(AppConstants.prefWifiOnly, value);

  int get concurrentDownloads =>
      _prefs.getInt(AppConstants.prefConcurrentDownloads) ??
      AppConstants.defaultMaxConcurrentDownloads;
  set concurrentDownloads(int value) =>
      _prefs.setInt(AppConstants.prefConcurrentDownloads, value);

  // Storage key kept as `settings.autoResume` for backward compatibility with
  // values already saved on-device; the setting itself actually controls
  // audio autoplay-on-open, not download resume (downloads always resume
  // automatically after an interrupted session — see DownloadManager.resumeInterrupted).
  bool get autoplayAudio => _prefs.getBool(AppConstants.prefAutoResume) ?? true;
  set autoplayAudio(bool value) => _prefs.setBool(AppConstants.prefAutoResume, value);

  SaveDestination get saveDestination {
    final raw = _prefs.getString(AppConstants.prefSaveDestination);
    return SaveDestination.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SaveDestination.askEveryTime,
    );
  }

  set saveDestination(SaveDestination value) =>
      _prefs.setString(AppConstants.prefSaveDestination, value.name);

  double get defaultPlaybackSpeed =>
      _prefs.getDouble(AppConstants.prefDefaultPlaybackSpeed) ?? 1.0;
  set defaultPlaybackSpeed(double value) =>
      _prefs.setDouble(AppConstants.prefDefaultPlaybackSpeed, value);

  bool get rememberPosition => _prefs.getBool(AppConstants.prefRememberPosition) ?? true;
  set rememberPosition(bool value) =>
      _prefs.setBool(AppConstants.prefRememberPosition, value);

  String get themeMode => _prefs.getString(AppConstants.prefThemeMode) ?? 'dark';
  set themeMode(String value) => _prefs.setString(AppConstants.prefThemeMode, value);

  // Optional self-hosted yt-dlp resolver backend (see backend/). Falls back
  // to the compile-time default baked in via `--dart-define-from-file=.env`
  // (see lib/core/constants/env.dart) when the user hasn't set an override
  // in Settings -> Advanced — both empty means the app relies solely on its
  // built-in scrapers, same as before this existed.
  String get resolverServerUrl =>
      _prefs.getString(AppConstants.prefResolverServerUrl) ?? Env.resolverServerUrl;
  set resolverServerUrl(String value) =>
      _prefs.setString(AppConstants.prefResolverServerUrl, value);

  // Kept in the iOS Keychain / Android Keystore via flutter_secure_storage,
  // not plaintext SharedPreferences — this is a real credential, and the app
  // otherwise positions itself as "privacy-first".
  String get resolverApiKey => _cachedResolverApiKey ?? Env.resolverApiKey;
  set resolverApiKey(String value) {
    _cachedResolverApiKey = value;
    unawaited(_secureStorage.write(key: _secureResolverApiKeyKey, value: value));
  }

  static const _recentLinksKey = 'importScreen.recentLinks';
  static const _maxRecentLinks = 10;

  List<String> get recentLinks => _prefs.getStringList(_recentLinksKey) ?? [];

  Future<void> pushRecentLink(String url) async {
    final links = recentLinks.toList()
      ..removeWhere((l) => l == url)
      ..insert(0, url);
    if (links.length > _maxRecentLinks) links.removeRange(_maxRecentLinks, links.length);
    await _prefs.setStringList(_recentLinksKey, links);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_recentLinksKey);
  }

  static const _playbackPositionPrefix = 'playbackPosition.';

  Duration? getPlaybackPosition(String mediaId) {
    final ms = _prefs.getInt('$_playbackPositionPrefix$mediaId');
    return ms == null ? null : Duration(milliseconds: ms);
  }

  Future<void> savePlaybackPosition(String mediaId, Duration position) =>
      _prefs.setInt('$_playbackPositionPrefix$mediaId', position.inMilliseconds);

  Future<void> clearPlaybackPosition(String mediaId) =>
      _prefs.remove('$_playbackPositionPrefix$mediaId');
}
