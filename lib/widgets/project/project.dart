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

import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/editors/arranger/arranger.dart';
import 'package:anthem/widgets/editors/pattern_editor/pattern_editor.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:anthem/widgets/project_explorer/project_explorer.dart';
import 'package:anthem/widgets/project_details/project_details.dart';
import 'package:anthem/widgets/project/project_footer.dart';

import 'project_header.dart';

class Project extends StatefulWidget {
  final ID id;

  const Project({Key? key, required this.id}) : super(key: key);

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  ProjectController? controller;

  @override
  Widget build(BuildContext context) {
    final projectModel = AnthemStore.instance.projects[widget.id]!;
    this.controller ??= ProjectController(projectModel);
    final controller = this.controller!;

    return Provider.value(
      value: projectModel,
      child: Provider.value(
        value: controller,
        child: Column(
          children: [
            ProjectHeader(
              projectID: widget.id,
            ),
            const SizedBox(
              height: 3,
            ),
            Expanded(
              child: Observer(builder: (context) {
                return Panel(
                  hidden: !projectModel.isProjectExplorerVisible,
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
                          visible: !projectModel.isDetailViewSelected,
                          child: const ProjectExplorer(),
                        ),
                      ),
                      Positioned.fill(
                        child: Visibility(
                          maintainAnimation: false,
                          maintainInteractivity: false,
                          maintainSemantics: false,
                          maintainSize: false,
                          maintainState: true,
                          visible: projectModel.isDetailViewSelected,
                          child: ProjectDetails(
                            selectedProjectDetails:
                                projectModel.selectedDetailView,
                          ),
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
                      panelContent: const PianoRoll(),
                      child: Panel(
                        hidden: !projectModel.isPatternEditorVisible,
                        orientation: PanelOrientation.left,
                        // Pattern editor
                        panelContent: const PatternEditor(),
                        child: const Arranger(),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(
              height: 3,
            ),
            const ProjectFooter(),
          ],
        ),
      ),
    );
  }
}
