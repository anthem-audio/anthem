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

import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/knob.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/editors/automation_editor/automation_editor.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
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

  const Project({super.key, required this.id});

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  ProjectController? controller;
  ProjectViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final projectModel = AnthemStore.instance.projects[widget.id]!;

    this.viewModel ??= ProjectViewModel();
    final viewModel = this.viewModel!;

    this.controller ??= ProjectController(projectModel, viewModel);
    final controller = this.controller!;

    return MultiProvider(
      providers: [
        Provider.value(value: projectModel),
        Provider.value(value: controller),
        Provider.value(value: viewModel),
      ],
      child: ShortcutConsumer(
        id: 'project',
        global: true,
        shortcutHandler: controller.onShortcut,
        rawKeyHandler: controller.onKey,
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
                const automationEditor = AutomationEditor();
                const channelRack = _KnobTest();
                const pianoRoll = PianoRoll();
                const mixer = Text('Mixer');

                final selectedEditor = Stack(
                  children: [
                    Visibility(
                      maintainState: true,
                      visible:
                          viewModel.selectedEditor == EditorKind.automation,
                      child: automationEditor,
                    ),
                    Visibility(
                      maintainState: true,
                      visible:
                          viewModel.selectedEditor == EditorKind.channelRack,
                      child: channelRack,
                    ),
                    Visibility(
                      maintainState: true,
                      visible: viewModel.selectedEditor == EditorKind.detail,
                      child: pianoRoll,
                    ),
                    Visibility(
                      maintainState: true,
                      visible: viewModel.selectedEditor == EditorKind.mixer,
                      child: mixer,
                    ),
                  ],
                );

                return Panel(
                  hidden: !projectModel.isProjectExplorerVisible,
                  orientation: PanelOrientation.left,
                  sizeBehavior: PanelSizeBehavior.pixels,
                  panelStartSize: 200,
                  panelMinSize: 200,
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
                          child: RepaintBoundary(
                            child: ProjectDetails(
                              selectedProjectDetails:
                                  projectModel.selectedDetailView,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  child: Panel(
                    hidden: true,
                    orientation: PanelOrientation.right,
                    sizeBehavior: PanelSizeBehavior.pixels,
                    panelStartSize: 200,
                    // Right panel
                    panelContent: Container(color: Theme.panel.main),

                    child: Panel(
                      orientation: PanelOrientation.bottom,
                      panelMinSize: 300,
                      contentMinSize: 300,
                      // Bottom panel
                      panelContent: RepaintBoundary(child: selectedEditor),
                      child: Panel(
                        hidden: !projectModel.isPatternEditorVisible,
                        orientation: PanelOrientation.left,
                        panelStartSize: 500,
                        panelMinSize: 500,
                        contentMinSize: 500,
                        sizeBehavior: PanelSizeBehavior.pixels,
                        // Pattern editor
                        panelContent:
                            const RepaintBoundary(child: PatternEditor()),
                        child: const RepaintBoundary(child: Arranger()),
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

class _KnobTest extends StatefulWidget {
  const _KnobTest({super.key});

  @override
  State<_KnobTest> createState() => __KnobTestState();
}

class __KnobTestState extends State<_KnobTest> {
  double value1 = 0.5;
  double value2 = 0.5;

  @override
  Widget build(BuildContext context) {
    return Background(
      type: BackgroundType.dark,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Knob(
              width: 20,
              height: 20,
              value: value1,
              onValueChanged: (value) {
                setState(() {
                  value1 = value;
                });
              },
            ),
            const SizedBox(
              width: 10,
            ),
            Knob(
              width: 40,
              height: 40,
              type: KnobType.pan,
              value: value2,
              onValueChanged: (value) {
                setState(() {
                  value2 = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
