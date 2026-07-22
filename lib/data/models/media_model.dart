import 'package:isar/isar.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/media_entity.dart';

part 'media_model.g.dart';

/// Isar collection for imported media. Mirrors [MediaEntity] 1:1; the
/// repository implementation is the only place that translates between the
/// two, so nothing above the data layer ever imports Isar directly.
@collection
class MediaModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  late String title;
  String? thumbnailPath;

  @enumerated
  late MediaType type;

  late int durationMs;
  late int sizeBytes;
  String? resolution;
  String? codec;
  late String format;

  @enumerated
  late SaveDestination saveLocation;

  late String path;
  late DateTime createdAt;

  @Index()
  bool favorite = false;

  @enumerated
  late MediaSource source;

  @Index()
  String? folderId;

  MediaEntity toEntity() => MediaEntity(
        id: id,
        title: title,
        thumbnailPath: thumbnailPath,
        type: type,
        duration: Duration(milliseconds: durationMs),
        sizeBytes: sizeBytes,
        resolution: resolution,
        codec: codec,
        format: format,
        saveLocation: saveLocation,
        path: path,
        createdAt: createdAt,
        favorite: favorite,
        source: source,
        folderId: folderId,
      );

  static MediaModel fromEntity(MediaEntity e) => MediaModel()
    ..id = e.id
    ..title = e.title
    ..thumbnailPath = e.thumbnailPath
    ..type = e.type
    ..durationMs = e.duration.inMilliseconds
    ..sizeBytes = e.sizeBytes
    ..resolution = e.resolution
    ..codec = e.codec
    ..format = e.format
    ..saveLocation = e.saveLocation
    ..path = e.path
    ..createdAt = e.createdAt
    ..favorite = e.favorite
    ..source = e.source
    ..folderId = e.folderId;
}
