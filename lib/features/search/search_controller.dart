import 'dart:async';
import 'package:get/get.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';

class LibrarySearchController extends GetxController {
  final MediaRepository _mediaRepository = Get.find<MediaRepository>();

  final query = ''.obs;
  final _allMedia = <MediaEntity>[].obs;
  final results = <MediaEntity>[].obs;
  StreamSubscription<List<MediaEntity>>? _mediaSub;

  @override
  void onInit() {
    super.onInit();
    _mediaSub = _mediaRepository.watchAll().listen((all) {
      _allMedia.value = all;
      _applyFilter();
    });
    debounce(query, (_) => _applyFilter(), time: const Duration(milliseconds: 200));
  }

  @override
  void onClose() {
    _mediaSub?.cancel();
    super.onClose();
  }

  void setQuery(String value) => query.value = value;

  void _applyFilter() {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) {
      results.value = [];
      return;
    }
    results.value = _allMedia.where((m) => m.title.toLowerCase().contains(q)).toList();
  }
}
