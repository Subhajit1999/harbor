import 'package:isar/isar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/isar_service.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../models/download_model.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final IsarService _isarService;
  DownloadRepositoryImpl(this._isarService);

  Isar get _db => _isarService.db;

  @override
  Future<List<DownloadEntity>> getAll() async {
    final models = await _db.downloadModels.where().sortByStartedAtDesc().findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<DownloadEntity>> getActive() async {
    final models = await _db.downloadModels
        .filter()
        .statusEqualTo(DownloadStatus.downloading)
        .or()
        .statusEqualTo(DownloadStatus.queued)
        .or()
        .statusEqualTo(DownloadStatus.paused)
        .findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<DownloadEntity?> getById(String id) async {
    final model = await _db.downloadModels.filter().idEqualTo(id).findFirst();
    return model?.toEntity();
  }

  @override
  Future<void> save(DownloadEntity download) async {
    await _db.writeTxn(() async {
      await _db.downloadModels.put(DownloadModel.fromEntity(download));
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.writeTxn(() async {
      await _db.downloadModels.filter().idEqualTo(id).deleteAll();
    });
  }

  @override
  Stream<List<DownloadEntity>> watchAll() {
    return _db.downloadModels
        .where()
        .watch(fireImmediately: true)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
