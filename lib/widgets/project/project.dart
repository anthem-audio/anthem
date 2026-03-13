/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/panel_border.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/editors/arranger/arranger.dart';
import 'package:anthem/widgets/editors/attribute_editor/attribute_editor.dart';
import 'package:anthem/widgets/editors/automation_editor/automation_editor.dart';
import 'package:anthem/widgets/editors/channel_rack/channel_rack.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/project_explorer/project_explorer.dart';
import 'package:anthem/widgets/project/project_footer.dart';
import 'package:anthem/widgets/project/project_view_model.dart';

import 'project_header.dart';

class Project extends StatefulWidget {
  final ProjectId id;

  const Project({super.key, required this.id});

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  @override
  Widget build(BuildContext context) {
    final projectModel = AnthemStore.instance.projects[widget.id]!;
    final serviceRegistry = ServiceRegistry.forProject(widget.id);
    final controller = serviceRegistry.projectController;
    final viewModel = serviceRegistry.projectViewModel;

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
        child: Column(
          children: [
            const RepaintBoundary(child: ProjectHeader()),
            Container(height: 1, color: AnthemTheme.panel.border),
            Expanded(
              child: Observer(
                builder: (context) {
                  const automationEditor = AutomationEditor();
                  const channelRack = ChannelRack();
                  const pianoRoll = PianoRoll();
                  const mixer = Text('Mixer');

                  final selectedEditorIndex =
                      switch (viewModel.selectedEditor) {
                        EditorKind.automation => 0,
                        EditorKind.channelRack => 1,
                        EditorKind.detail => 2,
                        EditorKind.mixer => 3,
                        null => null,
                      };

                  final selectedEditor = selectedEditorIndex == null
                      ? const SizedBox.shrink()
                      : PanelBorder(
                          panelKind: switch (viewModel.selectedEditor) {
                            .automation => .automationEditor,
                            .channelRack => .channelRack,
                            .detail => .pianoRoll,
                            .mixer => .mixer,
                            null => null,
                          },
                          child: IndexedStack(
                            index: selectedEditorIndex,
                            children: [
                              automationEditor,
                              channelRack,
                              pianoRoll,
                              mixer,
                            ],
                          ),
                        );

                  return Panel(
                    hidden: !projectModel.isDetailViewOpen,
                    orientation: .left,
                    sizeBehavior: .pixels,
                    panelStartSize: 200,
                    panelMinSize: 200,
                    // Left side-panel content
                    panelContent: const RepaintBoundary(
                      child: PanelBorder(child: AttributeEditor()),
                    ),

                    child: Panel(
                      hidden: !projectModel.isProjectExplorerOpen,
                      orientation: .right,
                      sizeBehavior: .pixels,
                      panelStartSize: 200,
                      // Right side-panel content
                      panelContent: const PanelBorder(child: ProjectExplorer()),

                      child: Panel(
                        orientation: .bottom,
                        panelMinSize: 200,
                        contentMinSize: 150,
                        hidden: viewModel.selectedEditor == null,
                        // Bottom panel content (selected editor)
                        panelContent: RepaintBoundary(child: selectedEditor),
                        child: _PanelOverlay(
                          builder: viewModel.topPanelOverlayContentBuilder,
                          close: () => viewModel.clearTopPanelOverlay(),
                          child: const RepaintBoundary(
                            child: PanelBorder(
                              panelKind: .arranger,
                              child: Arranger(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(color: AnthemTheme.panel.border, height: 1),
            const RepaintBoundary(child: ProjectFooter()),
          ],
        ),
      ),
    );
  }
}

class _PanelOverlay extends StatelessWidget {
  final Widget Function(BuildContext context)? builder;
  final void Function() close;
  final Widget child;

  const _PanelOverlay({this.builder, required this.close, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Original content
        Visibility(visible: builder == null, maintainState: true, child: child),

        // Background, if overlay is present
        if (builder != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: AnthemTheme.panel.main,
              ),
            ),
          ),

        // Close button, if overlay is present
        if (builder != null)
          Positioned(
            top: 3,
            right: 3,
            width: 26,
            height: 26,
            child: Button(
              icon: Icons.close,
              variant: ButtonVariant.label,
              onPress: close,
            ),
          ),

        // Overlay content
        if (builder != null) Positioned.fill(child: builder!(context)),
      ],
    );
  }
}
