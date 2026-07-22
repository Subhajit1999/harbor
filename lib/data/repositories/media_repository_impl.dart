import 'package:isar/isar.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/isar_service.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../models/media_model.dart';

class MediaRepositoryImpl implements MediaRepository {
  final IsarService _isarService;
  MediaRepositoryImpl(this._isarService);

  Isar get _db => _isarService.db;

  @override
  Future<List<MediaEntity>> getAll() async {
    final models = await _db.mediaModels.where().sortByCreatedAtDesc().findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<MediaEntity>> getByType(MediaTypeFilter type) async {
    if (type == MediaTypeFilter.all) return getAll();
    final targetType = type == MediaTypeFilter.video ? MediaType.video : MediaType.audio;
    final models = await _db.mediaModels
        .filter()
        .typeEqualTo(targetType)
        .sortByCreatedAtDesc()
        .findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<MediaEntity>> getFavorites() async {
    final models =
        await _db.mediaModels.filter().favoriteEqualTo(true).sortByCreatedAtDesc().findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<MediaEntity>> getByFolder(String folderId) async {
    final models =
        await _db.mediaModels.filter().folderIdEqualTo(folderId).sortByCreatedAtDesc().findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<MediaEntity?> getById(String id) async {
    final model = await _db.mediaModels.filter().idEqualTo(id).findFirst();
    return model?.toEntity();
  }

  @override
  Future<void> save(MediaEntity media) async {
    await _db.writeTxn(() async {
      await _db.mediaModels.put(MediaModel.fromEntity(media));
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.writeTxn(() async {
      await _db.mediaModels.filter().idEqualTo(id).deleteAll();
    });
  }

  @override
  Future<void> toggleFavorite(String id) async {
    await _db.writeTxn(() async {
      final model = await _db.mediaModels.filter().idEqualTo(id).findFirst();
      if (model != null) {
        model.favorite = !model.favorite;
        await _db.mediaModels.put(model);
      }
    });
  }

  @override
  Future<void> moveToFolder(String id, String? folderId) async {
    await _db.writeTxn(() async {
      final model = await _db.mediaModels.filter().idEqualTo(id).findFirst();
      if (model != null) {
        model.folderId = folderId;
        await _db.mediaModels.put(model);
      }
    });
  }

  @override
  Future<void> rename(String id, String title) async {
    await _db.writeTxn(() async {
      final model = await _db.mediaModels.filter().idEqualTo(id).findFirst();
      if (model != null) {
        model.title = title;
        await _db.mediaModels.put(model);
      }
    });
  }

  @override
  Stream<List<MediaEntity>> watchAll() {
    return _db.mediaModels
        .where()
        .watch(fireImmediately: true)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<int> totalStorageBytes() async {
    final models = await _db.mediaModels.where().findAll();
    return models.fold<int>(0, (sum, m) => sum + m.sizeBytes);
  }
}
