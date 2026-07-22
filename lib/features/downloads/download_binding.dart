import 'package:get/get.dart';
import 'download_queue_controller.dart';

class DownloadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DownloadQueueController>(() => DownloadQueueController());
  }
}
