import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/download_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/models/media_model.dart';

/// Owns the single Isar instance for the app. Registered as a permanent
/// GetX singleton (see [InitialBindings]) and opened once at startup before
/// runApp — every repository depends on this being ready.
class IsarService {
  late final Isar db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    db = await Isar.open(
      [MediaModelSchema, DownloadModelSchema, FolderModelSchema],
      directory: dir.path,
      inspector: false,
    );
  }
}
