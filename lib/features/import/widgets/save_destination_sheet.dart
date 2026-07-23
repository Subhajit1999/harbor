import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../import_controller.dart';

/// Bottom sheet shown after variant selection. Mirrors the spec: Photos /
/// Files / Always Ask, with a "remember choice" toggle so returning users
/// aren't asked every time if they don't want to be.
class SaveDestinationSheet extends StatefulWidget {
  const SaveDestinationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SaveDestinationSheet(),
    );
  }

  @override
  State<SaveDestinationSheet> createState() => _SaveDestinationSheetState();
}

class _SaveDestinationSheetState extends State<SaveDestinationSheet> {
  late SaveDestination _selected = () {
    final remembered = Get.find<SettingsService>().saveDestination;
    return remembered == SaveDestination.askEveryTime ? SaveDestination.photos : remembered;
  }();
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImportController>();

    Widget option(SaveDestination dest, IconData icon, String label) {
      final selected = _selected == dest;
      return ListTile(
        onTap: () => setState(() => _selected = dest),
        leading: Icon(icon, color: selected ? AppColors.accent : AppColors.textSecondaryDark),
        title: Text(label),
        trailing: Icon(
          selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
          color: selected ? AppColors.accent : AppColors.textSecondaryDark,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Save to', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          option(SaveDestination.photos, CupertinoIcons.photo, 'Photos'),
          option(SaveDestination.files, CupertinoIcons.folder, 'Files'),
          option(SaveDestination.askEveryTime, CupertinoIcons.question_circle, 'Always Ask'),
          SwitchListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v),
            title: const Text('Remember choice'),
            activeColor: AppColors.accent,
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Start Download',
            onPressed: () {
              final settings = Get.find<SettingsService>();
              settings.saveDestination =
                  _remember ? _selected : SaveDestination.askEveryTime;
              Navigator.of(context).pop();
              controller.confirmAndEnqueue(_selected);
            },
          ),
        ],
      ),
    );
  }
}
