import 'package:equatable/equatable.dart';

class FolderEntity extends Equatable {
  final String id;
  final String name;
  final String? coverImagePath;
  final DateTime createdAt;

  const FolderEntity({
    required this.id,
    required this.name,
    this.coverImagePath,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, coverImagePath, createdAt];
}
