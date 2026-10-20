/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/logic/application_settings.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_renderer.dart';
import 'package:anthem/widgets/main_window/settings_dialog.dart';
import 'package:anthem/widgets/main_window/settings_dialog_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsWidgetTestScreen extends StatefulWidget {
  final bool custom;

  const SettingsWidgetTestScreen({super.key, this.custom = false});

  @override
  State<SettingsWidgetTestScreen> createState() =>
      _SettingsWidgetTestScreenState();
}

class _SettingsWidgetTestScreenState extends State<SettingsWidgetTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb) return;
      final controller = SettingsDialogController(
        _PreviewSettings(custom: widget.custom),
      );
      await controller.load();
      if (!mounted) {
        controller.dispose();
        return;
      }
      ServiceRegistry.dialogController.showDialog(
        title: 'Settings',
        content: SettingsDialog(
          controller: controller,
          onClose: ServiceRegistry.dialogController.closeDialog,
        ),
        canDismiss: controller.canDismiss,
      );
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 440,
    child: DialogRenderer(
      child: ColoredBox(color: AnthemTheme.panel.backgroundDark),
    ),
  );
}

/// Preview changes stay in memory and never modify the user's preferences.
class _PreviewSettings extends ApplicationSettings {
  String? _override;
  _PreviewSettings({required bool custom}) : super(SharedPreferencesAsync()) {
    if (custom) {
      _override = defaultTargetPlatform == TargetPlatform.windows
          ? r'D:\Audio\Anthem projects'
          : '/home/artist/Audio/Anthem projects';
    }
  }

  @override
  Future<String?> get projectsDirectoryOverride async => _override;

  @override
  Future<String?> get defaultProjectsDirectory async =>
      defaultTargetPlatform == TargetPlatform.windows
      ? r'C:\Users\Artist\Documents\Anthem\Projects'
      : '/home/artist/Documents/Anthem/Projects';

  @override
  Future<void> setProjectsDirectoryOverride(String? directory) async {
    _override = directory;
  }
}
