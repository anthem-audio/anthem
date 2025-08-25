/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

enum PatternFilterKind { midi, audio, automation }

class PatternPicker extends StatefulObserverWidget {
  const PatternPicker({super.key});

  @override
  State<PatternPicker> createState() => _PatternPickerState();
}

class _PatternPickerState extends State<PatternPicker> {
  double patternHeight = 50;

  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(update);
  }

  @override
  void dispose() {
    scrollController.removeListener(update);
    scrollController.dispose();
    super.dispose();
  }

  void update() {
    setState(() {});
  }

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
              height: 38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: AnthemTheme.panel.border,
                            width: 1,
                          ),
                          color: AnthemTheme.panel.background,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Button(
                                icon: Icons.patternPickerHybrid,
                                hideBorder: true,
                                contentPadding: EdgeInsets.all(2),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(2),
                                  bottomLeft: Radius.circular(2),
                                ),
                                toggleState: true,
                              ),
                            ),
                            Container(
                              width: 1,
                              color: AnthemTheme.panel.border,
                            ),
                            Expanded(
                              child: Button(
                                icon: Icons.patternPickerMidi,
                                hideBorder: true,
                                contentPadding: EdgeInsets.all(2),
                                borderRadius: BorderRadius.circular(0),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: AnthemTheme.panel.border,
                            ),
                            Expanded(
                              child: Button(
                                icon: Icons.patternPickerAudio,
                                hideBorder: true,
                                contentPadding: EdgeInsets.all(2),
                                borderRadius: BorderRadius.circular(0),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: AnthemTheme.panel.border,
                            ),
                            Expanded(
                              child: Button(
                                icon: Icons.patternPickerAutomation,
                                hideBorder: true,
                                contentPadding: EdgeInsets.all(2),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(2),
                                  bottomRight: Radius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Button(
                      icon: Icons.add,
                      variant: ButtonVariant.ghost,
                      contentPadding: const EdgeInsets.all(0),
                      hint: [HintSection('click', 'Create a new pattern')],
                      width: 20,
                      onPress: () {
                        projectController.addPattern();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: AnthemTheme.panel.border),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AnthemTheme.panel.border,
                          width: 1,
                        ),
                        color: AnthemTheme.panel.background,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: (notification) {
                            // After metrics change (e.g., items added/removed or size change),
                            // rebuild so the ScrollbarRenderer reads updated extents immediately.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
                            return true;
                          },
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: project.sequence.patternOrder.length,
                            itemBuilder: (context, index) {
                              final patternID =
                                  project.sequence.patternOrder[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: SizedBox(
                                  height: patternHeight,
                                  child: Clip.fromPattern(
                                    patternId: patternID,
                                    ticksPerPixel: 5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AnthemTheme.panel.border,
                          width: 1,
                        ),
                      ),
                    ),
                    width: 17,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final handleStart =
                                  scrollController.position.extentBefore;
                              final handleEnd =
                                  scrollController.position.extentInside +
                                  handleStart;
                              return SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: ScrollbarRenderer(
                                  scrollRegionStart: 0,
                                  scrollRegionEnd:
                                      scrollController.position.extentTotal,
                                  handleStart: handleStart,
                                  handleEnd: handleEnd,
                                  onChange: (e) {
                                    scrollController.jumpTo(e.handleStart);
                                  },
                                ),
                              );
                            },
                          ),
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
