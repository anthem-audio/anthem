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

import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_row_divider.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme.dart';

class PatternEditor extends StatefulWidget {
  PatternEditor({Key? key}) : super(key: key);

  @override
  _PatternEditorState createState() => _PatternEditorState();
}

class _PatternEditorState extends State<PatternEditor> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatternEditorCubit, PatternEditorState>(
        builder: (context, state) {
      return Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Theme.panel.accent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(2),
                bottom: Radius.circular(1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 7),
                Button(
                  width: 28,
                  height: 28,
                  iconPath: "assets/icons/file/hamburger.svg",
                ),
                SizedBox(width: 4),
                SizedBox(width: 16, child: Center(child: ButtonRowDivider())),
                SizedBox(width: 4),
                Dropdown(width:169, height:28),
                Expanded(child: SizedBox()),
                Button(
                  width: 28,
                  height: 28,
                  iconPath: "assets/icons/pattern_editor/add-audio.svg",
                ),
                SizedBox(width: 4),
                Button(
                  width: 28,
                  height: 28,
                  iconPath: "assets/icons/pattern_editor/add-automation.svg",
                ),
                SizedBox(width: 7),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.panel.light,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(1),
                  bottom: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
