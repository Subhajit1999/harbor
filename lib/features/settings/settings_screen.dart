import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/harbor_scaffold.dart';
import 'settings_controller.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HarborScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          _SectionLabel('Downloads'),
          Obx(() => SwitchListTile(
                value: controller.wifiOnly.value,
                onChanged: controller.setWifiOnly,
                activeColor: AppColors.accent,
                title: const Text('Wi-Fi Only'),
              )),
          Obx(() => ListTile(
                title: const Text('Concurrent Downloads'),
                trailing: DropdownButton<int>(
                  value: controller.concurrentDownloads.value,
                  dropdownColor: AppColors.surfaceElevatedDark,
                  items: [1, 2, 3, 4]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setConcurrentDownloads(v);
                  },
                ),
              )),
          Obx(() => SwitchListTile(
                value: controller.autoplayAudio.value,
                onChanged: controller.setAutoplayAudio,
                activeColor: AppColors.accent,
                title: const Text('Autoplay Audio'),
                subtitle: const Text('Start playing audio automatically when opened'),
              )),
          const Divider(height: 32),
          _SectionLabel('Storage'),
          Obx(() => ListTile(
                title: const Text('Save Destination'),
                trailing: DropdownButton<SaveDestination>(
                  value: controller.saveDestination.value,
                  dropdownColor: AppColors.surfaceElevatedDark,
                  items: const [
                    DropdownMenuItem(value: SaveDestination.photos, child: Text('Photos')),
                    DropdownMenuItem(value: SaveDestination.files, child: Text('Files')),
                    DropdownMenuItem(
                        value: SaveDestination.askEveryTime, child: Text('Ask Every Time')),
                  ],
                  onChanged: (v) {
                    if (v != null) controller.setSaveDestination(v);
                  },
                ),
              )),
          Obx(() => ListTile(
                title: const Text('Library Storage'),
                trailing: Text(Formatters.bytes(controller.libraryStorageBytes.value)),
              )),
          Obx(() => ListTile(
                title: const Text('Cache Size'),
                trailing: Text(Formatters.bytes(controller.cacheBytes.value)),
              )),
          ListTile(
            title: const Text('Clear Cache', style: TextStyle(color: AppColors.accent)),
            onTap: controller.clearCache,
          ),
          const Divider(height: 32),
          _SectionLabel('Playback'),
          Obx(() => ListTile(
                title: const Text('Default Speed'),
                trailing: DropdownButton<double>(
                  value: controller.defaultPlaybackSpeed.value,
                  dropdownColor: AppColors.surfaceElevatedDark,
                  items: AppConstants.playbackSpeeds
                      .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setDefaultPlaybackSpeed(v);
                  },
                ),
              )),
          Obx(() => SwitchListTile(
                value: controller.rememberPosition.value,
                onChanged: controller.setRememberPosition,
                activeColor: AppColors.accent,
                title: const Text('Remember Position'),
              )),
          const Divider(height: 32),
          _SectionLabel('Advanced'),
          Obx(() => ListTile(
                title: const Text('Resolver Server URL'),
                subtitle: Text(
                  controller.resolverServerUrl.value.isEmpty
                      ? 'Not set — using built-in resolvers'
                      : controller.resolverServerUrl.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _editTextDialog(
                  context,
                  title: 'Resolver Server URL',
                  initialValue: controller.resolverServerUrl.value,
                  hintText: 'https://harbor-resolver-xxxx.onrender.com',
                  onSave: controller.setResolverServerUrl,
                ),
              )),
          Obx(() => ListTile(
                title: const Text('Resolver API Key'),
                subtitle: Text(
                  controller.resolverApiKey.value.isEmpty
                      ? 'Not set'
                      : '•' * controller.resolverApiKey.value.length.clamp(0, 24),
                ),
                onTap: () => _editTextDialog(
                  context,
                  title: 'Resolver API Key',
                  initialValue: controller.resolverApiKey.value,
                  hintText: 'Matches API_KEY on the server',
                  onSave: controller.setResolverApiKey,
                ),
              )),
          const Divider(height: 32),
          _SectionLabel('Privacy'),
          const ListTile(
            title: Text('No Analytics'),
            trailing: Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success),
          ),
          const ListTile(
            title: Text('No Tracking'),
            trailing: Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success),
          ),
          const ListTile(
            title: Text('Local Database Only'),
            trailing: Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success),
          ),
          ListTile(
            title: const Text('Clear History', style: TextStyle(color: AppColors.error)),
            onTap: controller.clearHistory,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

void _editTextDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String hintText,
  required ValueChanged<String> onSave,
}) {
  final textController = TextEditingController(text: initialValue);
  showCupertinoDialog(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CupertinoTextField(
          controller: textController,
          autofocus: true,
          placeholder: hintText,
        ),
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
            onSave(textController.text.trim());
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondaryDark,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
