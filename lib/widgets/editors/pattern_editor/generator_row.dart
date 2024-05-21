/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/pattern_editor/generator_row_automation.dart';
import 'package:anthem/widgets/editors/pattern_editor/generator_row_notes.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';

class GeneratorRow extends StatefulWidget {
  final ID generatorID;

  const GeneratorRow({
    Key? key,
    required this.generatorID,
  }) : super(key: key);

  @override
  State<GeneratorRow> createState() => _GeneratorRowState();
}

class _GeneratorRowState extends State<GeneratorRow> {
  MenuController contextMenuController = MenuController();

  bool secondaryDown = false;

  void openContext(Offset pos) {
    contextMenuController.open(pos);
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    PatternModel? getPattern() =>
        project.song.patterns[project.song.activePatternID];
    final generator = project.generators[widget.generatorID]!;
    final projectViewModel = Provider.of<ProjectViewModel>(context);

    // Context menu
    return Menu(
      menuController: contextMenuController,
      menuDef: MenuDef(
        children: [
          AnthemMenuItem(
            text: 'Delete',
            onSelected: () {
              // final projectController = Provider.of<ProjectController>(context, listen: false);

              // projectController.removeGenerator(widget.generatorID);
              // print('projectController.removeGenerator(widget.generatorID)');
            },
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          final generator = project.generators[widget.generatorID]!;

          switch (generator.generatorType) {
            case GeneratorType.instrument:
              {
                project.activeInstrumentID = widget.generatorID;
                break;
              }
            case GeneratorType.automation:
              {
                project.activeAutomationGeneratorID = widget.generatorID;
                break;
              }
          }

          projectViewModel.selectedEditor = switch (generator.generatorType) {
            GeneratorType.instrument => EditorKind.detail,
            GeneratorType.automation => EditorKind.automation,
          };
        },
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 127),
                // Generator name
                Observer(
                  builder: (context) {
                    final backgroundHoverColor =
                        HSLColor.fromColor(generator.color)
                            .withLightness(0.56)
                            .toColor();

                    return Listener(
                      onPointerDown: (e) {
                        if (e.buttons & kSecondaryButton != 0) {
                          secondaryDown = true;
                        }
                      },
                      onPointerUp: (e) {
                        if (secondaryDown) {
                          openContext(e.position);
                          secondaryDown = false;
                        }
                      },
                      child: Button(
                        width: 105,
                        height: 26,
                        backgroundColor: generator.color,
                        backgroundHoverColor: backgroundHoverColor,
                        backgroundPressColor: backgroundHoverColor,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Activity indicator
                Container(
                  width: 8,
                  height: 22,
                  decoration: BoxDecoration(
                    color: generator.color,
                    border: Border.all(color: Theme.panel.border),
                  ),
                ),
                const SizedBox(width: 8),
                // Content
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.panel.border),
                      borderRadius: const BorderRadius.all(Radius.circular(1)),
                      color: Theme.panel.main,
                    ),
                    child: Observer(builder: (context) {
                      final pattern = getPattern();

                      if (pattern == null) {
                        return const SizedBox();
                      }

                      final generator = project.generators[widget.generatorID];

                      if (generator == null) {
                        return const SizedBox();
                      }

                      if (generator.generatorType == GeneratorType.instrument) {
                        return GeneratorRowNotes(
                          pattern: pattern,
                          generatorID: widget.generatorID,
                          timeViewStart: 0,
                          // 1 bar is 100 pixels, can be tweaked (and should probably be set above?)
                          ticksPerPixel:
                              (project.song.ticksPerQuarter * 4) / 100,
                          color: generator.color,
                        );
                      } else if (generator.generatorType ==
                          GeneratorType.automation) {
                        return GeneratorRowAutomation(
                          pattern: pattern,
                          generatorID: widget.generatorID,
                          timeViewStart: 0,
                          // 1 bar is 100 pixels, can be tweaked (and should probably be set above?)
                          ticksPerPixel:
                              (project.song.ticksPerQuarter * 4) / 100,
                          color: generator.color,
                        );
                      } else {
                        throw Exception('Unsupported generator type');
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
