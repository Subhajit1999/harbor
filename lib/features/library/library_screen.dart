import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/harbor_scaffold.dart';
import '../../domain/entities/media_entity.dart';
import 'library_controller.dart';
import 'widgets/media_grid_tile.dart';

class LibraryScreen extends GetView<LibraryController> {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: HarborScaffold(
        title: 'Library',
        actions: [
          HeaderIconButton(
            icon: CupertinoIcons.search,
            onTap: () => Get.toNamed(AppRoutes.search),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: [
            Tab(text: 'Videos'),
            Tab(text: 'Audio'),
            Tab(text: 'Favorites'),
            Tab(text: 'Folders'),
          ],
        ),
        body: Obx(() => TabBarView(
              children: [
                _MediaGrid(items: controller.videos, emptyLabel: 'No videos yet'),
                _MediaGrid(items: controller.audio, emptyLabel: 'No audio yet'),
                _MediaGrid(items: controller.favorites, emptyLabel: 'No favorites yet'),
                _FoldersTab(),
              ],
            )),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<MediaEntity> items;
  final String emptyLabel;
  const _MediaGrid({required this.items, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: CupertinoIcons.rectangle_stack,
        title: emptyLabel,
        message: 'Imported media will appear here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) => MediaGridTile(media: items[i]),
    );
  }
}

class _FoldersTab extends GetView<LibraryController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.folders.isEmpty) {
        return EmptyState(
          icon: CupertinoIcons.folder,
          title: 'No folders yet',
          message: 'Create a folder to organize your library.',
          action: TextButton(
            onPressed: () => _createFolderDialog(context),
            child: const Text('New Folder'),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final folder in controller.folders)
            ListTile(
              leading: const Icon(CupertinoIcons.folder_fill, color: AppColors.accent),
              title: Text(folder.name),
              subtitle: Text('${controller.mediaInFolder(folder.id).length} items'),
              onTap: () => _showFolderContents(context, folder.id, folder.name),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _createFolderDialog(context),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('New Folder'),
          ),
        ],
      );
    });
  }

  void _createFolderDialog(BuildContext context) {
    final textController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('New Folder'),
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
            child: const Text('Create'),
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                controller.createFolder(textController.text.trim());
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showFolderContents(BuildContext context, String folderId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevatedDark,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Obx(() {
          final items = controller.mediaInFolder(folderId);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: CupertinoIcons.folder,
                        title: 'Folder is empty',
                        message: 'Move media into this folder from its details sheet.',
                      )
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, i) => MediaGridTile(media: items[i]),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
