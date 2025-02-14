/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

enum PatternFilterKind { midi, audio, automation }

class PatternPicker extends StatefulWidget {
  const PatternPicker({super.key});

  @override
  State<PatternPicker> createState() => _PatternPickerState();
}

class _PatternPickerState extends State<PatternPicker> {
  double patternHeight = 50;

  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final projectController = Provider.of<ProjectController>(context);

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController.position.notifyListeners();
        });
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ButtonTabs(
                      tabs: [
                        ButtonTabDef.withIcon(
                          icon: Icons.midi,
                          id: PatternFilterKind.midi,
                        ),
                        ButtonTabDef.withIcon(
                          icon: Icons.audio,
                          id: PatternFilterKind.audio,
                        ),
                        ButtonTabDef.withIcon(
                          icon: Icons.automation,
                          id: PatternFilterKind.automation,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  VerticalScaleControl(
                    min: 25,
                    max: 60,
                    value: patternHeight,
                    onChange: (value) {
                      setState(() {
                        patternHeight = value;
                      });
                      scrollController.position.notifyListeners();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Theme.panel.border, width: 1),
                        color: Theme.panel.accentDark,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Observer(
                            builder: (context) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children:
                                    project.sequence.patternOrder
                                        .map(
                                          (patternID) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 1,
                                            ),
                                            child: SizedBox(
                                              height: patternHeight,
                                              child: Clip.fromPattern(
                                                patternId: patternID,
                                                ticksPerPixel: 5,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 17,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Scrollbar(
                            controller: scrollController,
                            crossAxisSize: 17,
                            direction: ScrollbarDirection.vertical,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Button(
                          icon: Icons.add,
                          height: 17,
                          variant: ButtonVariant.ghost,
                          contentPadding: const EdgeInsets.all(0),
                          hint: 'Create a new pattern',
                          onPress: () {
                            projectController.addPattern();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
