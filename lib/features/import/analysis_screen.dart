import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/harbor_scaffold.dart';
import '../../domain/entities/media_variant.dart';
import 'import_controller.dart';
import 'widgets/save_destination_sheet.dart';

class AnalysisScreen extends GetView<ImportController> {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarborScaffold(
      title: 'Analysis',
      body: Obx(() {
        final meta = controller.metadata.value;
        if (meta == null) {
          return const EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No analysis available',
            message: 'Go back and analyze a link first.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: meta.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: meta.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppColors.surfaceElevatedDark),
                      )
                    : Container(color: AppColors.surfaceElevatedDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(meta.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                _MetaChip(icon: CupertinoIcons.clock, label: Formatters.duration(meta.duration)),
                const SizedBox(width: 8),
                _MetaChip(icon: CupertinoIcons.globe, label: meta.source.name),
              ],
            ),
            const SizedBox(height: 24),
            if (meta.videoVariants.isNotEmpty) ...[
              const Text('Video', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...meta.videoVariants.map((v) => _VariantTile(variant: v)),
              const SizedBox(height: 20),
            ],
            if (meta.audioVariants.isNotEmpty) ...[
              const Text('Audio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...meta.audioVariants.map((v) => _VariantTile(variant: v)),
            ],
          ],
        );
      }),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondaryDark),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }
}

class _VariantTile extends GetView<ImportController> {
  final MediaVariant variant;
  const _VariantTile({required this.variant});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedVariant.value?.id == variant.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          accented: selected,
          onTap: () async {
            controller.selectVariant(variant);
            await SaveDestinationSheet.show(context);
          },
          child: Row(
            children: [
              selected
                  ? GradientTint(
                      child: Icon(
                        variant.type.name == 'video'
                            ? CupertinoIcons.videocam
                            : CupertinoIcons.music_note,
                      ),
                    )
                  : Icon(
                      variant.type.name == 'video'
                          ? CupertinoIcons.videocam
                          : CupertinoIcons.music_note,
                      color: AppColors.textSecondaryDark,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variant.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      [
                        variant.container.toUpperCase(),
                        if (variant.codec != null) variant.codec!,
                        if (variant.estimatedSizeBytes != null)
                          Formatters.bytes(variant.estimatedSizeBytes!),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.textSecondaryDark),
            ],
          ),
        ),
      );
    });
  }
}
