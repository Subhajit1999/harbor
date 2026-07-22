import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/harbor_scaffold.dart';
import '../library/widgets/media_grid_tile.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarborScaffold(
      title: 'Harbor',
      actions: [
        HeaderIconButton(
          icon: CupertinoIcons.search,
          onTap: () => Get.toNamed(AppRoutes.search),
        ),
        const SizedBox(width: 8),
        HeaderIconButton(
          icon: CupertinoIcons.settings,
          onTap: () => Get.toNamed(AppRoutes.settings),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => controller.checkClipboard(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PasteLinkCard(),
            const SizedBox(height: 24),
            _QuickActionsRow(),
            const SizedBox(height: 24),
            Obx(() {
              if (controller.activeDownloads.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Continue Download',
                    onSeeAll: () => Get.toNamed(AppRoutes.downloadQueue),
                  ),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.activeDownloads.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final d = controller.activeDownloads[i];
                        return SizedBox(
                          width: 260,
                          child: GlassCard(
                            onTap: () => Get.toNamed(AppRoutes.downloadQueue),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(d.mediaTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                GradientProgressBar(value: d.progress, height: 4),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),
            SectionHeader(
              title: 'Recent Imports',
              onSeeAll: () => Get.toNamed(AppRoutes.library),
            ),
            Obx(() {
              if (controller.recentImports.isEmpty) {
                return const EmptyState(
                  icon: CupertinoIcons.tray,
                  title: 'Nothing imported yet',
                  message: 'Paste a link above or share one into Harbor to get started.',
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.recentImports.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, i) => MediaGridTile(media: controller.recentImports[i]),
              );
            }),
            const SizedBox(height: 24),
            _StorageUsageCard(),
          ],
        ),
      ),
    );
  }
}

class _PasteLinkCard extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final link = controller.clipboardLink.value;
      return GlassCard(
        onTap: () => Get.toNamed(AppRoutes.import, arguments: link),
        child: Row(
          children: [
            const Icon(CupertinoIcons.link, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                link != null ? 'Link detected — tap to import' : 'Paste a link to import',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 18, color: AppColors.textSecondaryDark),
          ],
        ),
      );
    });
  }
}

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        action(CupertinoIcons.square_arrow_down, 'Import', () => Get.toNamed(AppRoutes.import)),
        const SizedBox(width: 12),
        action(CupertinoIcons.arrow_down_circle, 'Downloads',
            () => Get.toNamed(AppRoutes.downloadQueue)),
        const SizedBox(width: 12),
        action(CupertinoIcons.rectangle_stack, 'Library', () => Get.toNamed(AppRoutes.library)),
      ],
    );
  }
}

class _StorageUsageCard extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() => GlassCard(
          child: Row(
            children: [
              const Icon(CupertinoIcons.chart_pie, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Storage Used', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      Formatters.bytes(controller.totalStorageBytes.value),
                      style: const TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.settings),
                child: const Text('Manage'),
              ),
            ],
          ),
        ));
  }
}
