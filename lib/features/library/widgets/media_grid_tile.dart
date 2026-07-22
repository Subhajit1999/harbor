import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_widgets.dart';
import '../../../domain/entities/media_entity.dart';
import 'media_details_sheet.dart';

class MediaGridTile extends StatelessWidget {
  final MediaEntity media;
  const MediaGridTile({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final thumb = media.thumbnailPath;
    return BouncyTap(
      onTap: () => Get.toNamed(AppRoutes.player, arguments: media),
      child: GestureDetector(
      onLongPress: () => MediaDetailsSheet.show(context, media),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceElevatedDark),
            if (thumb != null && File(thumb).existsSync())
              Image.file(File(thumb), fit: BoxFit.cover)
            else
              const Center(
                child: Icon(CupertinoIcons.play_rectangle, size: 36, color: AppColors.textSecondaryDark),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      Formatters.duration(media.duration),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                media.type == MediaType.video
                    ? CupertinoIcons.videocam_fill
                    : CupertinoIcons.music_note,
                size: 16,
                color: Colors.white70,
              ),
            ),
            if (media.favorite)
              const Positioned(
                top: 6,
                left: 6,
                child: GradientTint(child: Icon(CupertinoIcons.heart_fill, size: 14)),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
