import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/settings_service.dart';
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
      title: 'Download Options',
      body: Obx(() {
        final meta = controller.metadata.value;
        if (meta == null) {
          return const EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No analysis available',
            message: 'Go back and analyze a link first.',
          );
        }

        if (meta.videoVariants.isEmpty && meta.audioVariants.isEmpty) {
          // Belt-and-suspenders: a resolver should always throw
          // ResolverException instead of returning empty variants (that was
          // exactly the Instagram bug — see instagram_resolver.dart), but if
          // one ever does slip through, show this instead of a silent blank
          // screen with no download affordance.
          return const EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'Nothing downloadable found',
            message: 'This link didn\'t yield a video or audio stream. '
                'Double-check it\'s a public post and try again.',
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
            Text(
              meta.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SourceTag(source: meta.source),
                const SizedBox(width: 8),
                _MetaChip(icon: CupertinoIcons.clock, label: Formatters.duration(meta.duration)),
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
            final remembered = Get.find<SettingsService>().saveDestination;
            if (remembered != SaveDestination.askEveryTime) {
              controller.confirmAndEnqueue(remembered);
            } else {
              await SaveDestinationSheet.show(context);
            }
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _VariantTag(text: variant.container.toUpperCase()),
                        if (variant.codec != null) _VariantTag(text: variant.codec!),
                        if (variant.bitrateKbps != null) _VariantTag(text: '${variant.bitrateKbps} kbps'),
                        if (variant.estimatedSizeBytes != null)
                          _VariantTag(text: Formatters.bytes(variant.estimatedSizeBytes!)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.cloud_download, size: 22, color: AppColors.accentDark),
            ],
          ),
        ),
      );
    });
  }
}

class _VariantTag extends StatelessWidget {
  final String text;
  const _VariantTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
      ),
    );
  }
}
