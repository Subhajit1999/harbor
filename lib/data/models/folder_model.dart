import 'package:isar/isar.dart';
import '../../domain/entities/folder_entity.dart';

part 'folder_model.g.dart';

@collection
class FolderModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  late String name;
  String? coverImagePath;
  late DateTime createdAt;

  FolderEntity toEntity() => FolderEntity(
        id: id,
        name: name,
        coverImagePath: coverImagePath,
        createdAt: createdAt,
      );

  static FolderModel fromEntity(FolderEntity e) => FolderModel()
    ..id = e.id
    ..name = e.name
    ..coverImagePath = e.coverImagePath
    ..createdAt = e.createdAt;
}
