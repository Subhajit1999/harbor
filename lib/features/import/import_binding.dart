import 'package:get/get.dart';
import 'import_controller.dart';

/// Bound once on the Import route and kept alive through Analysis (they
/// share `ImportController`) — see AppPages for how the Analysis route
/// reuses this binding instead of creating a second instance.
class ImportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ImportController>(() => ImportController(), fenix: true);
  }
}
