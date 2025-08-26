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
import 'package:anthem/widgets/basic/button.dart';
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

    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            Observer(
              builder: (context) {
                return Button(
                  icon: Icons.browserPanel,
                  variant: ButtonVariant.label,
                  toggleState: projectModel.isDetailViewOpen,
                  onPress: () {
                    projectModel.isDetailViewOpen =
                        !projectModel.isDetailViewOpen;
                  },
                );
              },
            ),
            const SizedBox(width: 6),
            _Separator(),
            Button(
              variant: ButtonVariant.label,
              text: 'ARRANGE',
              toggleState: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            Button(
              variant: ButtonVariant.label,
              text: 'EDIT',
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            Button(
              variant: ButtonVariant.label,
              text: 'MIX',
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            _Separator(),
            const SizedBox(width: 6),
            Observer(
              builder: (context) {
                return Button(
                  variant: ButtonVariant.label,
                  icon: Icons.patternEditor,
                  toggleState: projectModel.isPatternEditorVisible,
                  onPress: () => projectModel.isPatternEditorVisible =
                      !projectModel.isPatternEditorVisible,
                  hint: projectModel.isPatternEditorVisible
                      ? [HintSection('click', 'Hide pattern editor')]
                      : [HintSection('click', 'Show pattern editor')],
                );
              },
            ),
            const SizedBox(width: 6),
            _Separator(),
            const SizedBox(width: 6),

            Observer(
              builder: (context) {
                return Button(
                  variant: ButtonVariant.label,
                  icon: Icons.detailEditor,
                  toggleState: viewModel.selectedEditor == EditorKind.detail,
                  onPress: () {
                    if (viewModel.selectedEditor == EditorKind.detail) {
                      viewModel.selectedEditor = null;
                    } else {
                      viewModel.selectedEditor = EditorKind.detail;
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 6),
            Observer(
              builder: (context) {
                return Button(
                  variant: ButtonVariant.label,
                  icon: Icons.automationEditor,
                  toggleState:
                      viewModel.selectedEditor == EditorKind.automation,
                  onPress: () {
                    if (viewModel.selectedEditor == EditorKind.automation) {
                      viewModel.selectedEditor = null;
                    } else {
                      viewModel.selectedEditor = EditorKind.automation;
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 6),
            Observer(
              builder: (context) {
                return Button(
                  variant: ButtonVariant.label,
                  icon: Icons.channelRack,
                  toggleState:
                      viewModel.selectedEditor == EditorKind.channelRack,
                  onPress: () {
                    if (viewModel.selectedEditor == EditorKind.channelRack) {
                      viewModel.selectedEditor = null;
                    } else {
                      viewModel.selectedEditor = EditorKind.channelRack;
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 6),
            Observer(
              builder: (context) {
                return Button(
                  variant: ButtonVariant.label,
                  icon: Icons.mixer,
                  toggleState: viewModel.selectedEditor == EditorKind.mixer,
                  onPress: () {
                    if (viewModel.selectedEditor == EditorKind.mixer) {
                      viewModel.selectedEditor = null;
                    } else {
                      viewModel.selectedEditor = EditorKind.mixer;
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 6),
            _Separator(),
            const SizedBox(width: 6),
            HintDisplay(),

            const Expanded(child: SizedBox()),
            Observer(
              builder: (context) {
                return Button(
                  icon: Icons.browserPanel,
                  variant: ButtonVariant.label,
                  toggleState: projectModel.isProjectExplorerOpen,
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

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(color: const Color(0xFF5E5E5E), width: 2, height: 24),
    );
  }
}
