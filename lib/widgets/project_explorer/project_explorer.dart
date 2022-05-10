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
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar.dart';
import 'package:anthem/widgets/basic/tree_view/model.dart';
import 'package:anthem/widgets/basic/tree_view/tree_view.dart';
import 'package:anthem/widgets/project_explorer/project_explorer_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({Key? key}) : super(key: key);

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  final ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectExplorerCubit, ProjectExplorerState>(
        builder: (context, state) {
      final project = Store.instance.projects[state.projectID]!;

      final arrangementsTree = TreeViewItemModel(
        name: "Arrangements",
        children: state.arrangementIDs
            .map((id) =>
                TreeViewItemModel(name: project.song.arrangements[id]!.name))
            .toList(),
      );

      final patternsTree = TreeViewItemModel(
        name: "Patterns",
        children: state.patternIDs
            .map((id) =>
                TreeViewItemModel(name: project.song.patterns[id]!.name))
            .toList(),
      );

      return Background(
        type: BackgroundType.dark,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 26),
              const SizedBox(height: 4),
              const SizedBox(height: 24),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.panel.accentDark,
                          border:
                              Border.all(color: Theme.panel.border, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TreeView(
                          scrollController: controller,
                          items: [
                            TreeViewItemModel(
                              name: "Current project",
                              children: [
                                arrangementsTree,
                                patternsTree,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Scrollbar(
                      controller: controller,
                      direction: ScrollbarDirection.vertical,
                      crossAxisSize: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
