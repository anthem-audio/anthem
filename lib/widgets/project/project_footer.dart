/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';

import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ProjectFooter extends StatelessWidget {
  const ProjectFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final projectController = Provider.of<ProjectController>(context);
    final projectModel = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<ProjectViewModel>(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.panel.main,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            Observer(builder: (context) {
              return ButtonTabs(
                tabs: [
                  ButtonTabDef.withIcon(icon: Icons.projectPanel, id: false),
                  ButtonTabDef.withIcon(icon: Icons.detailEditor, id: true),
                ],
                selected: projectModel.isDetailViewSelected,
                onChange: (selected) {
                  projectController.setActiveDetailView(selected);
                },
              );
            }),
            // Button(
            //   startIcon: Icons.projectPanel,
            //   toggleState: state.isProjectExplorerVisible,
            //   onPress: () => projectCubit.setIsProjectExplorerVisible(
            //     !state.isProjectExplorerVisible,
            //   ),
            // ),
            const SizedBox(width: 8),
            ButtonTabs(
              // selected: ProjectLayoutKind.arrange,
              tabs: [
                ButtonTabDef.withText(
                  text: 'ARRANGE',
                  id: ProjectLayoutKind.arrange,
                ),
                ButtonTabDef.withText(
                  text: 'EDIT',
                  id: ProjectLayoutKind.edit,
                ),
                ButtonTabDef.withText(
                  text: 'MIX',
                  id: ProjectLayoutKind.mix,
                ),
              ],
            ),
            const SizedBox(width: 8),
            Observer(builder: (context) {
              return Button(
                icon: Icons.patternEditor,
                width: 32,
                height: 32,
                toggleState: projectModel.isPatternEditorVisible,
                onPress: () => projectModel.isPatternEditorVisible =
                    !projectModel.isPatternEditorVisible,
                hint: projectModel.isPatternEditorVisible
                    ? 'Hide pattern editor'
                    : 'Show pattern editor',
              );
            }),
            const SizedBox(width: 8),
            ButtonTabs(
              // selected: EditorKind.detail,
              tabs: [
                ButtonTabDef.withIcon(
                  icon: Icons.detailEditor,
                  id: EditorKind.detail,
                ),
                ButtonTabDef.withIcon(
                  icon: Icons.automation,
                  id: EditorKind.automation,
                ),
                ButtonTabDef.withIcon(
                  icon: Icons.channelRack,
                  id: EditorKind.channelRack,
                ),
                ButtonTabDef.withIcon(
                  icon: Icons.mixer,
                  id: EditorKind.mixer,
                ),
              ],
            ),
            const Expanded(child: SizedBox()),
            Container(
              width: 304,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.panel.border),
                color: Theme.panel.accentDark,
              ),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Observer(builder: (context) {
                  return Text(
                    viewModel.hintText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.text.main,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            Button(
              icon: Icons.automationMatrixPanel,
              width: 32,
              height: 32,
            ),
          ],
        ),
      ),
    );
  }
}
