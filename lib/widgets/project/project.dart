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

import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/editors/arranger/arranger_cubit.dart';
import 'package:anthem/widgets/editors/arranger/arranger.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor_cubit.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_cubit.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/project_explorer/project_explorer_cubit.dart';
import 'package:anthem/widgets/project_explorer/project_explorer.dart';
import 'package:anthem/widgets/project_details/project_details.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:anthem/widgets/project/project_footer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';

import 'project_header.dart';

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
          const SizedBox(
            height: 3,
          ),
          Expanded(
            child: Panel(
              hidden: !state.isProjectExplorerVisible,
              orientation: PanelOrientation.left,
              panelStartSize: 200,
              // Left panel
              panelContent: Stack(
                children: [
                  Positioned.fill(
                    child: Visibility(
                      maintainAnimation: false,
                      maintainInteractivity: false,
                      maintainSemantics: false,
                      maintainSize: false,
                      maintainState: true,
                      visible: state.selectedDetailView == null,
                      child: BlocProvider<ProjectExplorerCubit>(
                        create: (context) => ProjectExplorerCubit(state.id),
                        child: const ProjectExplorer(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Visibility(
                      maintainAnimation: false,
                      maintainInteractivity: false,
                      maintainSemantics: false,
                      maintainSize: false,
                      maintainState: true,
                      visible: state.selectedDetailView != null,
                      child: const ProjectDetails(),
                    ),
                  ),
                ],
              ),

              child: Panel(
                hidden: true,
                orientation: PanelOrientation.right,
                // Right panel
                panelContent: Container(color: Theme.panel.main),

                child: Panel(
                  orientation: PanelOrientation.bottom,
                  // Bottom panel
                  panelContent: BlocProvider<PianoRollCubit>(
                    create: (context) => PianoRollCubit(projectID: state.id),
                    child: const PianoRoll(),
                  ),
                  child: Panel(
                    hidden: !state.isPatternEditorVisible,
                    orientation: PanelOrientation.left,
                    child: BlocProvider<ArrangerCubit>(
                      create: (context) => ArrangerCubit(projectID: state.id),
                      child: const Arranger(),
                    ),
                    // Pattern editor
                    panelContent: BlocProvider<PatternEditorCubit>(
                      create: (context) => PatternEditorCubit(
                          project: Store.instance.projects[state.id]!),
                      child: const PatternEditor(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          const ProjectFooter(),
        ],
      );
    });
  }
}
