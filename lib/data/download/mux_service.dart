import 'package:flutter/services.dart';

/// Bridges to native iOS code (AVFoundation's `AVMutableComposition`) to
/// combine a video-only track and an audio-only track into a single
/// playable file. This is required for YouTube's 1080p+ adaptive streams,
/// which are served as separate video/audio tracks.
///
/// The Dart side here is intentionally thin — it's a platform channel call.
/// The actual muxing implementation lives natively in
/// `ios/Runner/MuxHandler.swift` (see that file for the AVFoundation code
/// and the note on registering the channel in AppDelegate). This split
/// exists because there is no pure-Dart/Flutter way to mux media on iOS
/// without shelling out to ffmpeg, which we're deliberately avoiding to
/// keep the app lean — AVFoundation ships with iOS for free.
class MuxService {
  static const _channel = MethodChannel('harbor/mux');

  /// Combines [videoPath] and [audioPath] into a single file at
  /// [outputPath]. Returns the output path on success.
  Future<String> mux({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final result = await _channel.invokeMethod<String>('muxVideoAudio', {
      'videoPath': videoPath,
      'audioPath': audioPath,
      'outputPath': outputPath,
    });
    if (result == null) {
      throw Exception('Muxing failed: no output path returned from native side.');
    }
    return result;
  }
}
