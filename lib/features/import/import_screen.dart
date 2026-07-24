import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/harbor_scaffold.dart';
import 'import_controller.dart';

class ImportScreen extends GetView<ImportController> {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarborScaffold(
      title: 'Import',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.link, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller.linkController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Paste a YouTube, Instagram, or Facebook link',
                        hintStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      onSubmitted: (_) => controller.analyze(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.doc_on_clipboard, color: AppColors.accent),
                    onPressed: controller.pasteFromClipboard,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => PrimaryButton(
                  label: 'Analyze',
                  icon: CupertinoIcons.wand_stars,
                  loading: controller.isAnalyzing.value,
                  onPressed: controller.analyze,
                )),
            Obx(() {
              final error = controller.analysisError.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ErrorBanner(
                  message: error,
                  onRetry: () => controller.analyze(),
                ),
              );
            }),
            const SizedBox(height: 28),
            Obx(() => SectionHeader(
                  title: 'Recent Links',
                  trailingLabel: 'Clear All',
                  onSeeAll: controller.recentLinks.isEmpty
                      ? null
                      : () => _confirmClearAll(context, controller),
                )),
            Expanded(
              child: Obx(() {
                if (controller.recentLinks.isEmpty) {
                  return const EmptyState(
                    icon: CupertinoIcons.clock,
                    title: 'No recent links',
                    message: 'Links you analyze will show up here for quick re-import.',
                  );
                }
                return ListView.separated(
                  itemCount: controller.recentLinks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final link = controller.recentLinks[i];
                    return GlassCard(
                      onTap: () {
                        controller.linkController.text = link;
                        controller.analyze(link);
                      },
                      onLongPress: () => _showLinkActions(context, controller, link),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.clock, size: 18, color: AppColors.textSecondaryDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

void _showLinkActions(BuildContext context, ImportController controller, String link) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      message: Text(link, maxLines: 2, overflow: TextOverflow.ellipsis),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            controller.linkController.text = link;
            controller.analyze(link);
          },
          child: const Text('Re-import'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(ctx);
            controller.removeRecentLink(link);
          },
          child: const Text('Delete'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
}

void _confirmClearAll(BuildContext context, ImportController controller) {
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear all recent links?'),
      content: const Text('This removes every link from your recent history.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  ).then((confirmed) {
    if (confirmed == true) controller.clearRecentLinks();
  });
}
