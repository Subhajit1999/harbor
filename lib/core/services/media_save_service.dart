import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

const _tag = 'MediaSaveService';

/// Handles the two save destinations the product spec calls for: Photos
/// and Files (via the app's own Documents directory, which iOS surfaces
/// inside the Files app when `UIFileSharingEnabled` +
/// `LSSupportsOpeningDocumentsInPlace` are set — see ios/Runner/Info.plist
/// notes in the README).
///
/// Photos save is a thin platform-channel call into
/// `ios/Runner/PhotosSaveHandler.swift`, which talks to `PHPhotoLibrary`
/// directly — used instead of a Flutter plugin so the permission request
/// and any save failure return an exact, debuggable error instead of being
/// swallowed inside a third-party wrapper.
class MediaSaveService {
  static const _channel = MethodChannel('harbor/photos');

  /// Saves the file at [sourcePath] into the Photos library. Returns true
  /// on success, false on any failure (permission denied, native save
  /// error) — deliberately non-fatal, since Harbor always keeps its own
  /// Files copy regardless (see [saveToFiles]), so a Photos failure alone
  /// shouldn't fail the whole download. Audio isn't a Photos-library asset
  /// type at all — callers should route audio downloads to Files only.
  Future<bool> saveToPhotos({
    required String sourcePath,
    required MediaType type,
    required String title,
  }) async {
    if (type == MediaType.audio) return false;

    try {
      final result = await _channel.invokeMethod<bool>('saveToPhotos', {
        'path': sourcePath,
        'isVideo': true,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.w(_tag, 'saveToPhotos failed: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Copies the file into Harbor's own Documents directory, under a
  /// user-facing "Harbor" folder, where it's addressable from the iOS
  /// Files app.
  Future<String> saveToFiles({
    required String sourcePath,
    required String fileName,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docs.path, 'Harbor'));
    if (!await destDir.exists()) await destDir.create(recursive: true);
    final destPath = p.join(destDir.path, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
