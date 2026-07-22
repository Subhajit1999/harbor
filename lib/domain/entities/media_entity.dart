import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// Domain-level representation of an imported piece of media. This is what
/// the UI and use cases work with — the Isar collection (data layer) maps
/// to/from this so persistence details never leak into features.
class MediaEntity extends Equatable {
  final String id;
  final String title;
  final String? thumbnailPath;
  final MediaType type;
  final Duration duration;
  final int sizeBytes;
  final String? resolution;
  final String? codec;
  final String format;
  final SaveDestination saveLocation;
  final String path;
  final DateTime createdAt;
  final bool favorite;
  final MediaSource source;
  final String? folderId;

  const MediaEntity({
    required this.id,
    required this.title,
    this.thumbnailPath,
    required this.type,
    required this.duration,
    required this.sizeBytes,
    this.resolution,
    this.codec,
    required this.format,
    required this.saveLocation,
    required this.path,
    required this.createdAt,
    this.favorite = false,
    required this.source,
    this.folderId,
  });

  MediaEntity copyWith({
    String? title,
    String? thumbnailPath,
    bool? favorite,
    String? folderId,
    String? path,
  }) {
    return MediaEntity(
      id: id,
      title: title ?? this.title,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      type: type,
      duration: duration,
      sizeBytes: sizeBytes,
      resolution: resolution,
      codec: codec,
      format: format,
      saveLocation: saveLocation,
      path: path ?? this.path,
      createdAt: createdAt,
      favorite: favorite ?? this.favorite,
      source: source,
      folderId: folderId ?? this.folderId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        thumbnailPath,
        type,
        duration,
        sizeBytes,
        resolution,
        codec,
        format,
        saveLocation,
        path,
        createdAt,
        favorite,
        source,
        folderId,
      ];
}
