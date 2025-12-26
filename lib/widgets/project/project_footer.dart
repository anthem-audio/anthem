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
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/hint/hint_display.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/project/project_view_model.dart';

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ProjectFooter extends StatelessWidget {
  const ProjectFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<ProjectViewModel>(context);

    return Container(
      color: AnthemTheme.panel.backgroundLight,
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          spacing: 8,
          children: [
            Observer(
              builder: (context) {
                return Button(
                  icon: Icons.browserPanel,
                  toggleState: projectModel.isDetailViewOpen,
                  width: 28,
                  contentPadding: const EdgeInsets.all(4),
                  onPress: () {
                    projectModel.isDetailViewOpen =
                        !projectModel.isDetailViewOpen;
                  },
                );
              },
            ),

            TextButtonTabs(
              tabs: [
                (label: 'Arrange', onSelect: () {}),
                (label: 'Edit', onSelect: () {}),
                (label: 'Mix', onSelect: () {}),
              ],
              selectedIndex: 0,
            ),

            Observer(
              builder: (context) {
                return Button(
                  icon: Icons.patternEditor,
                  toggleState: projectModel.isPatternEditorVisible,
                  width: 24,
                  onPress: () => projectModel.isPatternEditorVisible =
                      !projectModel.isPatternEditorVisible,
                  hint: projectModel.isPatternEditorVisible
                      ? [HintSection('click', 'Hide pattern editor')]
                      : [HintSection('click', 'Show pattern editor')],
                );
              },
            ),

            Observer(
              builder: (context) {
                Widget separator() =>
                    Container(width: 1, color: AnthemTheme.panel.border);
                const contentPadding = EdgeInsets.symmetric(vertical: 4);

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AnthemTheme.panel.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: .stretch,
                    children: [
                      Button(
                        icon: Icons.detailEditor,
                        toggleState: viewModel.selectedEditor == .detail,
                        hideBorder: true,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                        width: 26,
                        contentPadding: contentPadding,
                        onPress: () {
                          if (viewModel.selectedEditor == .detail) {
                            viewModel.selectedEditor = null;
                          } else {
                            viewModel.selectedEditor = .detail;
                            viewModel.activePanel = .pianoRoll;
                          }
                        },
                      ),
                      separator(),
                      Button(
                        icon: Icons.automationEditor,
                        toggleState: viewModel.selectedEditor == .automation,
                        hideBorder: true,
                        borderRadius: BorderRadius.zero,
                        width: 26,
                        contentPadding: contentPadding,
                        onPress: () {
                          if (viewModel.selectedEditor == .automation) {
                            viewModel.selectedEditor = null;
                          } else {
                            viewModel.selectedEditor = .automation;
                            viewModel.activePanel = .automationEditor;
                          }
                        },
                      ),
                      separator(),
                      Button(
                        icon: Icons.channelRack,
                        toggleState: viewModel.selectedEditor == .channelRack,
                        hideBorder: true,
                        borderRadius: BorderRadius.zero,
                        width: 26,
                        contentPadding: contentPadding,
                        onPress: () {
                          if (viewModel.selectedEditor == .channelRack) {
                            viewModel.selectedEditor = null;
                          } else {
                            viewModel.selectedEditor = .channelRack;
                            viewModel.activePanel = .channelRack;
                          }
                        },
                      ),
                      separator(),
                      Button(
                        icon: Icons.mixer,
                        toggleState: viewModel.selectedEditor == .mixer,
                        hideBorder: true,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                        width: 26,
                        contentPadding: contentPadding,
                        onPress: () {
                          if (viewModel.selectedEditor == .mixer) {
                            viewModel.selectedEditor = null;
                          } else {
                            viewModel.selectedEditor = .mixer;
                            viewModel.activePanel = .mixer;
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            HintDisplay(),

            const Expanded(child: SizedBox()),

            Observer(
              builder: (context) {
                return Button(
                  icon: Icons.browserPanel,
                  toggleState: projectModel.isProjectExplorerOpen,
                  width: 28,
                  contentPadding: const EdgeInsets.all(4),
                  onPress: () {
                    projectModel.isProjectExplorerOpen =
                        !projectModel.isProjectExplorerOpen;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
