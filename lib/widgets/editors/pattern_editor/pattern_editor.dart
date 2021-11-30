/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_row_divider.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';
import 'generator_row.dart';
import 'generator_row_cubit.dart';

class PatternEditor extends StatefulWidget {
  const PatternEditor({Key? key}) : super(key: key);

  @override
  _PatternEditorState createState() => _PatternEditorState();
}

class _PatternEditorState extends State<PatternEditor> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatternEditorCubit, PatternEditorState>(
        builder: (context, state) {
      final menuController = MenuController();

      return Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Theme.panel.accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
                bottom: Radius.circular(1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 7),
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
                    width: 28,
                    height: 28,
                    iconPath: "assets/icons/file/hamburger.svg",
                    showMenuIndicator: true,
                    onPress: () {
                      menuController.open?.call();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(
                    width: 16, child: Center(child: ButtonRowDivider())),
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
                  selectedID: state.activePatternID.toString(),
                  onChanged: (idStr) {
                    final id = idStr == null ? 0 : int.parse(idStr);
                    context.read<PatternEditorCubit>().setActivePattern(id);
                  },
                ),
                const Expanded(child: SizedBox()),
                Button(
                    width: 28,
                    height: 28,
                    iconPath: "assets/icons/pattern_editor/add-audio.svg",
                    onPress: () {
                      context.read<PatternEditorCubit>().addInstrument(
                          "Instrument ${(Random()).nextInt(100).toString()}");
                    }),
                const SizedBox(width: 4),
                Button(
                    width: 28,
                    height: 28,
                    iconPath: "assets/icons/pattern_editor/add-automation.svg",
                    onPress: () {
                      context.read<PatternEditorCubit>().addController(
                          "Controller ${(Random()).nextInt(100).toString()}");
                    }),
                const SizedBox(width: 7),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Column(
              children: state.generatorIDList.map<Widget>((id) {
                    final instrument = state.instruments[id];
                    final controller = state.controllers[id];

                    // TODO: provide type to child
                    if (instrument != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: BlocProvider(
                          create: (context) => GeneratorRowCubit(
                            projectID: state.projectID,
                            patternID: state.activePatternID,
                            generatorID: id,
                          ),
                          child: GeneratorRow(),
                        ),
                      );
                    }

                    if (controller != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: BlocProvider(
                          create: (context) => GeneratorRowCubit(
                            projectID: state.projectID,
                            patternID: state.activePatternID,
                            generatorID: id,
                          ),
                          child: GeneratorRow(),
                        ),
                      );
                    }

                    throw Error();
                  }).toList() +
                  [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.panel.main,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(1),
                            bottom: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
            ),
          ),
        ],
      );
    });
  }
}
