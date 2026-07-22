import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/media_entity.dart';
import '../library_controller.dart';

/// Details/actions sheet reachable by long-pressing a media tile — mirrors
/// the "Details" screen from the product spec (metadata + Rename/Move/
/// Share/Delete/Export) without needing a full dedicated route for what is,
/// in practice, a short-lived action sheet.
class MediaDetailsSheet extends StatelessWidget {
  final MediaEntity media;
  const MediaDetailsSheet({super.key, required this.media});

  static Future<void> show(BuildContext context, MediaEntity media) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MediaDetailsSheet(media: media),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LibraryController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(media.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${Formatters.relativeDate(media.createdAt)} · ${Formatters.bytes(media.sizeBytes)} · '
            '${Formatters.duration(media.duration)}'
            '${media.resolution != null ? ' · ${media.resolution}' : ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(
              media.favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              color: AppColors.accent,
            ),
            title: Text(media.favorite ? 'Remove from Favorites' : 'Add to Favorites'),
            onTap: () {
              controller.toggleFavorite(media.id);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.pencil, color: AppColors.accent),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(context).pop();
              _showRenameDialog(context, controller);
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_up, color: AppColors.accent),
            title: const Text('Share'),
            onTap: () {
              Navigator.of(context).pop();
              controller.share(media);
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right, color: AppColors.accent),
            title: const Text('Export'),
            onTap: () {
              Navigator.of(context).pop();
              controller.export(media);
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.delete, color: AppColors.error),
            title: const Text('Delete', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.of(context).pop();
              controller.delete(media);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, LibraryController controller) {
    final textController = TextEditingController(text: media.title);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(controller: textController, autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () {
              controller.rename(media.id, textController.text.trim());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
