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

import 'package:anthem/logic/commands/sequence_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/digit_control.dart';
import 'package:anthem/widgets/basic/controls/time_signature_control.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/horizontal_meter_simple.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:flutter/material.dart' hide Icons;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../basic/icon.dart';

class ProjectHeader extends StatelessWidget {
  const ProjectHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AnthemTheme.panel.accent,
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
        Button(
          icon: Icons.undo,
          width: 24,
          onPress: () {
            projectController.undo();
          },
          hint: [HintSection('click', 'Undo (Ctrl+Z)')],
        ),
        const SizedBox(width: 4),
        Button(
          icon: Icons.redo,
          width: 24,
          onPress: () {
            projectController.redo();
          },
          hint: [HintSection('click', 'Redo (Ctrl+Shift+Z)')],
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

        _PlayStopButtonGroup(),
      ],
    );
  }
}

class _PlayStopButtonGroup extends StatelessWidget {
  const _PlayStopButtonGroup();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AnthemTheme.control.border),
      ),
      child: Row(
        children: [
          Button(
            hideBorder: true,
            icon: Icons.play,
            height: 24,
            width: 24,
            contentPadding: EdgeInsets.all(3),
            hint: [HintSection('click', 'Play')],
            onPress: () {
              final projectModel = Provider.of<ProjectModel>(
                context,
                listen: false,
              );

              if (projectModel.engineState != EngineState.running) {
                return;
              }

              projectModel.sequence.isPlaying = true;
            },
          ),
          Container(width: 1, color: AnthemTheme.control.border),
          Button(
            hideBorder: true,
            icon: Icons.stop,
            height: 24,
            width: 24,
            contentPadding: EdgeInsets.all(3),
            hint: [HintSection('click', 'Stop')],
            onPress: () {
              final projectModel = Provider.of<ProjectModel>(
                context,
                listen: false,
              );
              projectModel.sequence.isPlaying = false;
            },
          ),
        ],
      ),
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
      size: DigitDisplaySize.large,
      decimalPlaces: 2,
      minCharacterCount: 6,
      hint: 'Set the project tempo',
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
          builder: (context, cpuValue) {
            return Observer(
              builder: (context) {
                var value = cpuValue ?? 0;
                bool engineIsRunning = true;

                final projectModel = Provider.of<ProjectModel>(
                  context,
                  listen: false,
                );
                if (projectModel.engineState != EngineState.running) {
                  // If the engine is not running, we don't want to show the CPU usage
                  // as it will be 0 and misleading.
                  value = 0;
                  engineIsRunning = false;
                }

                return HorizontalMeterSimple(
                  width: 60,
                  value: value,
                  label: engineIsRunning ? '${(value * 100).round()}%' : '--%',
                );
              },
            );
          },
          config: VisualizationSubscriptionConfig.max('cpu'),
          minimumUpdateInterval: const Duration(milliseconds: 1000),
        ),
      ],
    );
  }
}
