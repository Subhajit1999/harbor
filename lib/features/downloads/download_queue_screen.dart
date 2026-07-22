import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'download_queue_controller.dart';
import 'widgets/download_card.dart';

class DownloadQueueScreen extends GetView<DownloadQueueController> {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Obx(() {
        if (controller.downloads.isEmpty) {
          return const EmptyState(
            icon: CupertinoIcons.arrow_down_circle,
            title: 'No downloads yet',
            message: 'Imports you queue will show up here with live progress.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.downloads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = controller.downloads[i];
            return Dismissible(
              key: ValueKey(d.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(CupertinoIcons.delete, color: AppColors.error),
              ),
              onDismissed: (_) => controller.cancel(d.id),
              child: DownloadCard(
                download: d,
                onPause: () => controller.pause(d.id),
                onResume: () => controller.resume(d.id),
                onCancel: () => controller.cancel(d.id),
                onRetry: () => controller.retry(d.id),
              ),
            );
          },
        );
      }),
    );
  }
}
