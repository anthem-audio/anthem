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

import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../project_header.dart';
import '../../theme.dart';

class Project extends StatelessWidget {
  const Project({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectCubit, ProjectState>(builder: (context, state) {
      return Column(
        children: [
          ProjectHeader(
            projectID: state.id,
          ),
          SizedBox(
            height: 3,
          ),
          Expanded(
            // left panel
            child: Panel(
              orientation: PanelOrientation.Left,
              panelContent: Container(color: Theme.panel.main),

              // right panel
              child: Panel(
                orientation: PanelOrientation.Right,
                panelContent: Container(color: Theme.panel.main),
                child: Panel(
                  orientation: PanelOrientation.Bottom,
                  child: Panel(
                    orientation: PanelOrientation.Left,
                    child: Container(color: Theme.panel.main),
                    panelContent: BlocProvider<PatternEditorCubit>(
                      create: (context) =>
                          PatternEditorCubit(projectID: state.id),
                      child: PatternEditor(),
                    ),
                  ),
                  panelContent: Container(color: Theme.panel.main),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 3,
          ),
          Container(
            height: 42,
            color: Theme.panel.light,
          )
        ],
      );
    });
  }
}
