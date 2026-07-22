import '../entities/media_entity.dart';

abstract class MediaRepository {
  Future<List<MediaEntity>> getAll();
  Future<List<MediaEntity>> getByType(MediaTypeFilter type);
  Future<List<MediaEntity>> getFavorites();
  Future<List<MediaEntity>> getByFolder(String folderId);
  Future<MediaEntity?> getById(String id);
  Future<void> save(MediaEntity media);
  Future<void> delete(String id);
  Future<void> toggleFavorite(String id);
  Future<void> moveToFolder(String id, String? folderId);
  Future<void> rename(String id, String title);
  Stream<List<MediaEntity>> watchAll();
  Future<int> totalStorageBytes();
}

enum MediaTypeFilter { video, audio, all }
