import 'package:isar/isar.dart';
import '../../core/services/isar_service.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/repositories/folder_repository.dart';
import '../models/folder_model.dart';

class FolderRepositoryImpl implements FolderRepository {
  final IsarService _isarService;
  FolderRepositoryImpl(this._isarService);

  Isar get _db => _isarService.db;

  @override
  Future<List<FolderEntity>> getAll() async {
    final models = await _db.folderModels.where().sortByCreatedAtDesc().findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> save(FolderEntity folder) async {
    await _db.writeTxn(() async {
      await _db.folderModels.put(FolderModel.fromEntity(folder));
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.writeTxn(() async {
      await _db.folderModels.filter().idEqualTo(id).deleteAll();
    });
  }

  @override
  Stream<List<FolderEntity>> watchAll() {
    return _db.folderModels
        .where()
        .watch(fireImmediately: true)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
