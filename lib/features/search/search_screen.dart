import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/harbor_scaffold.dart';
import '../library/widgets/media_grid_tile.dart';
import 'search_controller.dart';

class SearchScreen extends GetView<LibrarySearchController> {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarborScaffold(
      titleWidget: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlassDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.search, size: 17, color: AppColors.textSecondaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Search your library',
                  hintStyle: TextStyle(color: AppColors.textSecondaryDark),
                ),
                onChanged: controller.setQuery,
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.query.value.isEmpty) {
          return const EmptyState(
            icon: CupertinoIcons.search,
            title: 'Search Harbor',
            message: 'Find anything you\'ve imported by title.',
          );
        }
        if (controller.results.isEmpty) {
          return const EmptyState(
            icon: CupertinoIcons.search,
            title: 'No matches',
            message: 'Try a different search term.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.results.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, i) => MediaGridTile(media: controller.results[i]),
        );
      }),
    );
  }
}
