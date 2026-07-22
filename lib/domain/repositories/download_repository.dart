import '../entities/download_entity.dart';

abstract class DownloadRepository {
  Future<List<DownloadEntity>> getAll();
  Future<List<DownloadEntity>> getActive();
  Future<DownloadEntity?> getById(String id);
  Future<void> save(DownloadEntity download);
  Future<void> delete(String id);
  Stream<List<DownloadEntity>> watchAll();
}
