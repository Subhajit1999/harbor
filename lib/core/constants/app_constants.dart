/// App-wide constants. Kept here rather than scattered as magic numbers/strings
/// throughout the codebase.
class AppConstants {
  AppConstants._();

  static const String appName = 'Harbor';

  // Isar
  static const String isarSchemaVersion = '1';

  // Download
  static const int defaultMaxConcurrentDownloads = 2;
  static const int maxRetryAttempts = 3;
  static const Duration retryBackoff = Duration(seconds: 3);

  // Cache
  static const String thumbnailCacheDir = 'thumbnails';
  static const String mediaStorageDir = 'media';

  // Player
  static const List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Preferences keys (SharedPreferences-backed settings)
  static const String prefWifiOnly = 'settings.wifiOnly';
  static const String prefConcurrentDownloads = 'settings.concurrentDownloads';
  static const String prefAutoResume = 'settings.autoResume';
  static const String prefSaveDestination = 'settings.saveDestination';
  static const String prefThemeMode = 'settings.themeMode';
  static const String prefDefaultPlaybackSpeed = 'settings.defaultPlaybackSpeed';
  static const String prefRememberPosition = 'settings.rememberPosition';
}

enum SaveDestination { photos, files, askEveryTime }

enum MediaType { video, audio }

enum MediaSource { youtube, instagram, facebook, unknown }

// `processing`/`saving` appended at the end (not inserted) — Isar stores
// this enum by ordinal index, so existing persisted records must keep
// their indices. `processing` = native mux/audio-extraction in progress;
// `saving` = moving the finished file to its Photos/Files save
// destination — distinct so the UI can show an accurate message for each
// instead of one generic "processing" covering both.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
  processing,
  saving,
}
