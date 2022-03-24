/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';
import '../../basic/icon.dart';
import 'generator_row.dart';
import 'generator_row_cubit.dart';

class PatternEditor extends StatefulWidget {
  const PatternEditor({Key? key}) : super(key: key);

  @override
  _PatternEditorState createState() => _PatternEditorState();
}

class _PatternEditorState extends State<PatternEditor> {
  double nextHue = 0;
  ScrollController verticalScrollController = ScrollController();

  Color getColor() {
    final color = HSLColor.fromAHSL(1, nextHue, 0.33, 0.5).toColor();
    nextHue = (nextHue + 330) % 360;
    return color;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatternEditorCubit, PatternEditorState>(
        builder: (context, state) {
      final menuController = MenuController();

      return NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (notification) {
          WidgetsBinding.instance?.addPostFrameCallback((_) {
            verticalScrollController.position.notifyListeners();
          });
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: Background(
            type: BackgroundType.dark,
            borderRadius: const BorderRadius.all(
              Radius.circular(2),
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
                        menuDef: MenuDef(children: [
                          MenuItem(
                              text: "New pattern",
                              onSelected: () {
                                context.read<PatternEditorCubit>().addPattern(
                                    "Pattern ${(Random()).nextInt(100).toString()}");
                              })
                        ]),
                        child: Button(
                          // width: 28,
                          // height: 28,
                          startIcon: Icons.kebab,
                          showMenuIndicator: true,
                          onPress: () {
                            menuController.open?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Dropdown(
                        width: 169,
                        height: 28,
                        items: state.patternList.map(
                          (item) {
                            return DropdownItem(
                              id: item.id.toString(),
                              name: item.name,
                            );
                          },
                        ).toList(),
                        selectedID: state.activePatternID?.toString(),
                        onChanged: (idStr) {
                          final id = idStr == null ? 0 : int.parse(idStr);
                          context
                              .read<PatternEditorCubit>()
                              .setActivePattern(id);
                        },
                      ),
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
                                  child: Column(
                                    children:
                                        state.generatorIDList.map<Widget>((id) {
                                      final instrument = state.instruments[id];
                                      final controller = state.controllers[id];

                                      // TODO: provide type to child
                                      if (instrument != null) {
                                        return BlocProvider(
                                          create: (context) =>
                                              GeneratorRowCubit(
                                            projectID: state.projectID,
                                            patternID: state.activePatternID,
                                            generatorID: id,
                                          ),
                                          child: const GeneratorRow(),
                                        );
                                      }

                                      if (controller != null) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 1),
                                          child: BlocProvider(
                                            create: (context) =>
                                                GeneratorRowCubit(
                                              projectID: state.projectID,
                                              patternID: state.activePatternID,
                                              generatorID: id,
                                            ),
                                            child: const GeneratorRow(),
                                          ),
                                        );
                                      }

                                      throw Error();
                                    }).toList(),
                                  ),
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
                          onPress: () {
                            context.read<PatternEditorCubit>().addInstrument(
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
      );
    });
  }
}
