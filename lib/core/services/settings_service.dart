import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Thin typed wrapper over SharedPreferences for the handful of user
/// preferences Harbor has (Settings screen). Deliberately not using Isar for
/// this — these are simple scalar values, not queryable records, so a
/// second storage engine would be overkill.
class SettingsService {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  Future<void> removeRecentLink(String url) async {
    final links = recentLinks.toList()..removeWhere((l) => l == url);
    await _prefs.setStringList(_recentLinksKey, links);
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
