/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'dart:convert';

import 'package:anthem/commands/sequence_commands.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/digit_control.dart';
import 'package:anthem/widgets/basic/controls/time_signature_control.dart';
import 'package:anthem/widgets/basic/horizontal_meter_simple.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/widgets/debug/widget_test_area.dart';
import 'package:anthem/widgets/main_window/main_window_controller.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../basic/icon.dart';

class ProjectHeader extends StatelessWidget {
  const ProjectHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        color: Theme.panel.accent,
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            Expanded(flex: 1, child: _LeftGroup()),
            Center(child: _MiddleGroup()),
            Expanded(flex: 1, child: _RightGroup()),
          ],
        ),
      ),
    );
  }
}

class _LeftGroup extends StatelessWidget {
  const _LeftGroup();

  @override
  Widget build(BuildContext context) {
    final projectController = context.read<ProjectController>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProjectMenu(),
        const SizedBox(width: 4),
        Button(
          icon: Icons.undo,
          onPress: () {
            projectController.undo();
          },
          hint: 'Undo (Ctrl+Z)',
        ),
        const SizedBox(width: 4),
        Button(
          icon: Icons.redo,
          onPress: () {
            projectController.redo();
          },
          hint: 'Redo (Ctrl+Shift+Z)',
        ),
      ],
    );
  }
}

class _MiddleGroup extends StatelessWidget {
  const _MiddleGroup();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 4,
      children: [
        _TempoControl(),
        TimeSignatureControl(),

        // The goal is a spacer of width 16, which is 8 plus two spacers of 4
        // provided by the Row
        SizedBox(width: 8),

        Button(
          icon: Icons.play,
          height: 24,
          width: 24,
          contentPadding: EdgeInsets.all(3),
          onPress: () {
            final projectModel = Provider.of<ProjectModel>(
              context,
              listen: false,
            );
            projectModel.sequence.isPlaying = true;
          },
        ),
        Button(
          icon: Icons.stop,
          height: 24,
          width: 24,
          contentPadding: EdgeInsets.all(3),
          onPress: () {
            final projectModel = Provider.of<ProjectModel>(
              context,
              listen: false,
            );
            projectModel.sequence.isPlaying = false;
          },
        ),
      ],
    );
  }
}

class _TempoControl extends StatefulObserverWidget {
  const _TempoControl();

  @override
  State<_TempoControl> createState() => _TempoControlState();
}

class _TempoControlState extends State<_TempoControl> {
  int originalTempo = 0;

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);

    return DigitControl(
      decimalPlaces: 2,
      minCharacterCount: 6,
      hint: 'Set the tempo',
      hintUnits: 'beats per minute',
      value: projectModel.sequence.beatsPerMinute,
      onStart: () {
        originalTempo = projectModel.sequence.beatsPerMinuteRaw;
      },
      onChanged: (value) {
        projectModel.sequence.beatsPerMinuteRaw = (value.clamp(10, 999) * 100)
            .round();
      },
      onEnd: () {
        final newTempo = projectModel.sequence.beatsPerMinuteRaw;

        if (newTempo == originalTempo) {
          return;
        }

        projectModel.push(
          SetTempoCommand(oldRawTempo: originalTempo, newRawTempo: newTempo),
        );
      },
    );
  }
}

class _RightGroup extends StatelessWidget {
  const _RightGroup();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        VisualizationBuilder.double(
          builder: (context, value) {
            value ??= 0;

            return HorizontalMeterSimple(
              width: 60,
              value: value,
              label: '${(value * 100).round()}%',
            );
          },
          config: VisualizationSubscriptionConfig.max('cpu'),
          minimumUpdateInterval: const Duration(milliseconds: 1000),
        ),
      ],
    );
  }
}

class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu();

  @override
  Widget build(BuildContext context) {
    final menuController = AnthemMenuController();
    final mainWindowController = context.read<MainWindowController>();

    final project = Provider.of<ProjectModel>(context);

    return Menu(
      menuController: menuController,
      menuDef: MenuDef(
        children: [
          AnthemMenuItem(
            text: 'New project',
            hint: 'Create a new project',
            onSelected: () async {
              final projectId = await mainWindowController.newProject();
              mainWindowController.switchTab(projectId);
            },
          ),
          AnthemMenuItem(
            text: 'Load project...',
            hint: 'Load a project',
            onSelected: () {
              mainWindowController.loadProject().then((projectId) {
                if (projectId != null) {
                  mainWindowController.switchTab(projectId);
                }
              });
            },
          ),
          Separator(),
          AnthemMenuItem(
            text: 'Save',
            hint: 'Save the active project',
            onSelected: () {
              mainWindowController.saveProject(project.id, false);
            },
          ),
          AnthemMenuItem(
            text: 'Save as...',
            hint: 'Save the active project to a new location',
            onSelected: () {
              mainWindowController.saveProject(project.id, true);
            },
          ),
          Separator(),
          if (kDebugMode)
            AnthemMenuItem(
              text: 'Debug',
              submenu: MenuDef(
                children: [
                  AnthemMenuItem(
                    text: 'Print project JSON (UI)',
                    hint: 'Print the project JSON as reported by the UI',
                    onSelected: () async {
                      // ignore: avoid_print
                      print(
                        jsonEncode(
                          AnthemStore
                              .instance
                              .projects[AnthemStore.instance.activeProjectId]!
                              .toJson(),
                        ),
                      );
                    },
                  ),
                  AnthemMenuItem(
                    text: 'Print project JSON (engine)',
                    hint: 'Print the project as JSON as reported by the engine',
                    onSelected: () async {
                      // ignore: avoid_print
                      print(
                        await AnthemStore
                            .instance
                            .projects[AnthemStore.instance.activeProjectId]!
                            .engine
                            .modelSyncApi
                            .debugGetEngineJson(),
                      );
                    },
                  ),
                  Separator(),
                  AnthemMenuItem(
                    text: 'Open widget test area',
                    onSelected: () {
                      final projectViewModel = Provider.of<ProjectViewModel>(
                        context,
                        listen: false,
                      );

                      projectViewModel.topPanelOverlayContentBuilder =
                          (context) => const WidgetTestArea();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      child: Button(
        icon: Icons.hamburger,
        showMenuIndicator: true,
        onPress: () {
          menuController.open();
        },
        hint: 'File...',
      ),
    );
  }
}
