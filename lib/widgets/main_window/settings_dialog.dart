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

import 'dart:async';

import 'package:anthem/logic/application_settings.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/main_window/settings_dialog_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Opens application settings, independently of the active project.
void showSettingsDialog({
  ApplicationSettings? settings,
  DialogController? dialogs,
}) {
  // There are no browser application settings yet.
  if (kIsWeb) return;
  final dialogController = dialogs ?? ServiceRegistry.dialogController;
  final controller = SettingsDialogController(
    settings ?? ServiceRegistry.applicationSettings,
  );
  dialogController.showDialog(
    title: 'Settings',
    content: SettingsDialog(
      controller: controller,
      onClose: dialogController.closeDialog,
    ),
    canDismiss: controller.canDismiss,
  );
}

/// Owns and disposes its dialog-scoped [controller].
class SettingsDialog extends StatefulWidget {
  final SettingsDialogController controller;
  final VoidCallback onClose;

  const SettingsDialog({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoaded) unawaited(widget.controller.load());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await widget.controller.save() && mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSection(
                title: 'General',
                child: controller.isLoading
                    ? Text(
                        'Loading settings…',
                        style: TextStyle(
                          color: AnthemTheme.text.main,
                          fontSize: 11,
                        ),
                      )
                    : controller.isLoaded
                    ? _SettingsRow(
                        label: 'Project folder',
                        child: _DirectorySetting(controller: controller),
                      )
                    : const SizedBox.shrink(),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.error!,
                  style: const TextStyle(
                    color: Color(0xFFF08080),
                    fontSize: 11,
                  ),
                ),
                if (!controller.isLoaded) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SettingsButton(
                      text: 'Retry',
                      onPress: controller.load,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Container(height: 1, color: AnthemTheme.panel.borderLight),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SettingsButton(
                    text: 'Cancel',
                    variant: ButtonVariant.ghost,
                    enabled: !controller.isSaving && !controller.isChoosing,
                    onPress: widget.onClose,
                  ),
                  const SizedBox(width: 6),
                  _SettingsButton(
                    text: controller.isSaving ? 'Saving…' : 'Save',
                    enabled: controller.canSave,
                    onPress: _save,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shared spacing and alignment for dense groups of settings.
class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: AnthemTheme.text.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AnthemTheme.panel.border),
          ),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(
          label,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: child),
    ],
  );
}

/// One joined control: source selector, resolved path, and folder picker.
class _DirectorySetting extends StatelessWidget {
  final SettingsDialogController controller;

  const _DirectorySetting({required this.controller});

  @override
  Widget build(BuildContext context) {
    final useDefault = controller.isUsingSystemDefault;
    final enabled = !controller.isBusy;
    final pathText = useDefault
        ? controller.projectsDirectory == null
              ? 'System default (unavailable)'
              : 'System default (${controller.projectsDirectory})'
        : controller.projectsDirectory ?? 'Choose folder…';
    return Container(
      height: 28,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: AnthemTheme.control.background,
        border: Border.all(color: AnthemTheme.control.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Dropdown(
            key: const ValueKey('projects-directory-mode'),
            width: 80,
            height: 24,
            selectedID: useDefault ? 'default' : 'custom',
            allowNoSelection: false,
            enabled: enabled,
            enableScrollSelection: false,
            variant: ButtonVariant.label,
            hideBorder: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            items: const [
              DropdownItem(id: 'default', name: 'Default'),
              DropdownItem(id: 'custom', name: 'Custom'),
            ],
            onChanged: (id) {
              if (id == 'default') controller.useDefault();
              if (id == 'custom') controller.useCustom();
            },
          ),
          Container(width: 1, color: AnthemTheme.control.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                pathText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: useDefault || !enabled
                      ? AnthemTheme.text.disabled
                      : AnthemTheme.text.main,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          _SettingsButton(
            key: const ValueKey('projects-directory-browse'),
            text: 'Choose project folder',
            icon: Icons.folder,
            width: 24,
            variant: ButtonVariant.label,
            enabled: enabled && !useDefault,
            onPress: controller.browse,
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final String text;
  final IconDef? icon;
  final double? width;
  final ButtonVariant variant;
  final bool enabled;
  final VoidCallback onPress;

  const _SettingsButton({
    super.key,
    required this.text,
    this.icon,
    this.width,
    this.variant = ButtonVariant.main,
    this.enabled = true,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: text,
    excludeSemantics: true,
    onTap: enabled ? onPress : null,
    child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Button(
        height: 24,
        width: width,
        text: icon == null ? text : null,
        icon: icon,
        variant: variant,
        hideBorder: variant == ButtonVariant.label,
        contentPadding: EdgeInsets.symmetric(horizontal: icon == null ? 8 : 3),
        interactable: enabled,
        onPress: onPress,
      ),
    ),
  );
}
