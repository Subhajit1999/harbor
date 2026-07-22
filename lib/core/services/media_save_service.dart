import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../constants/app_constants.dart';

/// Handles the two save destinations the product spec calls for: Photos
/// (via the native photo library) and Files (via the app's own Documents
/// directory, which iOS surfaces inside the Files app when
/// `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` are set —
/// see ios/Runner/Info.plist notes in the README).
class MediaSaveService {
  Future<bool> requestPhotosPermission() async {
    final status = await Permission.photosAddOnly.request();
    return status.isGranted || status.isLimited;
  }

  /// Saves the file at [sourcePath] into the Photos library. Returns true
  /// on success.
  Future<bool> saveToPhotos({
    required String sourcePath,
    required MediaType type,
    required String title,
  }) async {
    final granted = await requestPhotosPermission();
    if (!granted) return false;

    final AssetEntity? asset = type == MediaType.video
        ? await PhotoManager.editor.saveVideo(File(sourcePath), title: title)
        : await PhotoManager.editor.saveImage(
            await File(sourcePath).readAsBytes(),
            title: title,
            filename: title,
          );
    return asset != null;
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
