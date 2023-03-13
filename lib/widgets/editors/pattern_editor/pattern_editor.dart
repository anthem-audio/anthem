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

import 'dart:math';

import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_controller.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'generator_row.dart';

class PatternEditor extends StatefulWidget {
  const PatternEditor({Key? key}) : super(key: key);

  @override
  State<PatternEditor> createState() => _PatternEditorState();
}

class _PatternEditorState extends State<PatternEditor> {
  double nextHue = 0;
  ScrollController verticalScrollController = ScrollController();

  PatternEditorController? controller;

  Color getColor() {
    final color = HSLColor.fromAHSL(1, nextHue, 0.33, 0.5).toColor();
    nextHue = (nextHue + 330) % 360;
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final projectController = Provider.of<ProjectController>(context);
    controller ??= PatternEditorController(project: project);

    final menuController = MenuController();

    return Provider.value(
      value: controller!,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            verticalScrollController.position.notifyListeners();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.panel.main,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Menu(
                        menuController: menuController,
                        menuDef: MenuDef(
                          children: [
                            AnthemMenuItem(
                              text: "New pattern",
                              onSelected: () {
                                projectController.addPattern();
                              },
                            )
                          ],
                        ),
                        child: Button(
                          width: 26,
                          height: 26,
                          startIcon: Icons.kebab,
                          onPress: () {
                            menuController.open?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Observer(builder: (context) {
                        return Dropdown(
                          width: 169,
                          height: 26,
                          items: project.song.patternOrder.map(
                            (id) {
                              final pattern = project.song.patterns[id]!;
                              return DropdownItem(
                                id: id,
                                name: pattern.name,
                              );
                            },
                          ).toList(),
                          selectedID: project.song.activePatternID?.toString(),
                          onChanged: (id) {
                            project.song.activePatternID = id;
                          },
                        );
                      }),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Background(
                            type: BackgroundType.light,
                            border: Border.all(color: Theme.panel.border),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(2)),
                            child: SingleChildScrollView(
                              controller: verticalScrollController,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: SizeChangedLayoutNotifier(
                                  child: Observer(builder: (context) {
                                    return Column(
                                      children: project.generatorList
                                          .map<Widget>((id) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 1),
                                          child: GeneratorRow(generatorID: id),
                                        );
                                      }).toList(),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Scrollbar(
                          controller: verticalScrollController,
                          crossAxisSize: 17,
                          direction: ScrollbarDirection.vertical,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 17,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(width: 136),
                        Button(
                          width: 105,
                          contentPadding: EdgeInsets.zero,
                          startIcon: Icons.add,
                          onPress: () {
                            controller!.addGenerator(
                              "Instrument ${(Random()).nextInt(100).toString()}",
                              getColor(),
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
