import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/gradient_widgets.dart';
import 'player_controller.dart';

class PlayerScreen extends GetView<PlayerController> {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(title: Text(controller.media.title)),
      body: Obx(() {
        if (!controller.isReady.value) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return controller.media.type == MediaType.video
            ? _VideoPlayerBody()
            : _AudioPlayerBody();
      }),
    );
  }
}

class _VideoPlayerBody extends GetView<PlayerController> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.videoController!.value.aspectRatio,
        child: Chewie(controller: controller.chewieController!),
      ),
    );
  }
}

class _AudioPlayerBody extends GetView<PlayerController> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevatedDark,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const GradientTint(
              child: Icon(CupertinoIcons.music_note, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(controller.media.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Obx(() => Column(
                children: [
                  Slider(
                    value: controller.position.value.inMilliseconds
                        .clamp(0, controller.duration.value.inMilliseconds)
                        .toDouble(),
                    max: controller.duration.value.inMilliseconds.toDouble().clamp(1, double.infinity),
                    activeColor: AppColors.accent,
                    onChanged: (v) => controller.seek(Duration(milliseconds: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Formatters.duration(controller.position.value)),
                      Text(Formatters.duration(controller.duration.value)),
                    ],
                  ),
                ],
              )),
          const SizedBox(height: 16),
          Obx(() => IconButton(
                iconSize: 64,
                icon: GradientTint(
                  child: Icon(
                    controller.isPlaying.value
                        ? CupertinoIcons.pause_circle_fill
                        : CupertinoIcons.play_circle_fill,
                  ),
                ),
                onPressed: controller.togglePlay,
              )),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Obx(() => DropdownButton<double>(
                    value: controller.playbackSpeed.value,
                    dropdownColor: AppColors.surfaceElevatedDark,
                    items: AppConstants.playbackSpeeds
                        .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.setSpeed(v);
                    },
                  )),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => _showSleepTimerPicker(context),
                icon: const Icon(CupertinoIcons.moon_zzz, color: AppColors.accent),
                label: Obx(() => Text(
                      controller.sleepTimerRemaining.value != null
                          ? Formatters.duration(controller.sleepTimerRemaining.value!)
                          : 'Sleep Timer',
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevatedDark,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in [5, 15, 30, 60])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () {
                  controller.setSleepTimer(Duration(minutes: minutes));
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              title: const Text('Cancel Timer'),
              onTap: () {
                controller.cancelSleepTimer();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
