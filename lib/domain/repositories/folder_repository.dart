import '../entities/folder_entity.dart';

abstract class FolderRepository {
  Future<List<FolderEntity>> getAll();
  Future<void> save(FolderEntity folder);
  Future<void> delete(String id);
  Stream<List<FolderEntity>> watchAll();
}
