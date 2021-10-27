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

import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';

class GeneratorRow extends StatelessWidget {
  final int id;

  const GeneratorRow({Key? key, required this.id}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final random = Random();

    return BlocBuilder<PatternEditorCubit, PatternEditorState>(
        builder: (context, state) {
      return GestureDetector(
        onTap: () {
          BlocProvider.of<ProjectCubit>(context).setActiveInstrumentID(id);
        },
        child: SizedBox(
          height: 42,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(1),
                    right: Radius.circular(0),
                  ),
                  color: Color.fromARGB(
                    255,
                    random.nextInt(255),
                    random.nextInt(255),
                    random.nextInt(255),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(0),
                      right: Radius.circular(1),
                    ),
                    color: Theme.panel.light,
                  ),
                  child: Row(children: [
                    SizedBox(width: 270),
                    // ...
                  ]),
                ),
              )
            ],
          ),
        ),
      );
    });
  }
}
