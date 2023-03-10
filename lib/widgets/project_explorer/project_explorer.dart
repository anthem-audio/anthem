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

import 'dart:async';

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/button_tabs.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:anthem/widgets/basic/tree_view/tree_view.dart';
import 'package:anthem/widgets/project_explorer/project_explorer_cubit.dart';
import 'package:anthem/widgets/project/project_controller.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({Key? key}) : super(key: key);

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  final scrollController = ScrollController();
  final searchBoxController = TextEditingController();
  String searchText = "";

  @override
  void initState() {
    super.initState();
    searchBoxController.addListener(() {
      setState(() {
        searchText = searchBoxController.value.text;
      });
    });
  }

  StreamSubscription<List<StateChange>>? stateChangeHandle;

  // I'm trying a new pattern here. This widget uses many things from across
  // the state tree, and getting them all into a view model is a lot of work
  // for not much real benefit.
  //
  // Instead, we subscribe to a bunch of change events here and just re-
  // render when they fire. That way, we can pull info directly from the main
  // model.
  void initStateChangeListenerIfNeeded(ID projectID) {
    if (stateChangeHandle != null) return;

    final project = AnthemStore.instance.projects[projectID]!;

    project.stateChangeStream.listen(_onStateChanged);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onStateChanged(List<StateChange> changes) {
    for (final change in changes) {
      change.whenOrNull(
        pattern: (patternChange) {
          patternChange.mapOrNull(
            // When dragging the time signature, this fires a lot
            timeSignatureChangeListUpdated: (value) => setState(() {}),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectController = Provider.of<ProjectController>(context);

    return BlocBuilder<ProjectExplorerCubit, ProjectExplorerState>(
      builder: (context, state) {
        initStateChangeListenerIfNeeded(state.projectID);

        final project = AnthemStore.instance.projects[state.projectID]!;

        final arrangementsTree = TreeViewItemModel(
          key: "projectArrangementsFolder",
          label: "Arrangements",
          children: state.arrangementIDs
              .map(
                (id) => TreeViewItemModel(
                  key: "arrangement-$id",
                  label: project.song.arrangements[id]!.name,
                  onClick: () => projectController.setActiveDetailView(
                    true,
                    ArrangementDetailViewKind(id),
                  ),
                ),
              )
              .toList(),
        );

        final patternsTree = TreeViewItemModel(
          key: "projectPatternsFolder",
          label: "Patterns",
          children: state.patternIDs
              .map(
                (patternID) => TreeViewItemModel(
                  key: "pattern-$patternID",
                  label: project.song.patterns[patternID]!.name,
                  onClick: () => projectController.setActiveDetailView(
                    true,
                    PatternDetailViewKind(patternID),
                  ),
                  children: [
                    getMarkersItem(
                      pattern: project.song.patterns[patternID],
                      onClick: (changeID) {
                        projectController.setActiveDetailView(
                          true,
                          TimeSignatureChangeDetailViewKind(
                            changeID: changeID,
                            patternID: patternID,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
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
                SizedBox(
                  height: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Button(startIcon: Icons.kebab, width: 26),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ButtonTabs(
                          tabs: [
                            ButtonTabDef.withIcon(
                                id: "project", icon: Icons.audio),
                            ButtonTabDef.withIcon(
                                id: "files", icon: Icons.file),
                            ButtonTabDef.withIcon(
                                id: "plugins", icon: Icons.plugin),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: TextBox(
                    controller: searchBoxController,
                  ),
                ),
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
                            filterText: searchText == "" ? null : searchText,
                            scrollController: scrollController,
                            items: [
                              TreeViewItemModel(
                                key: "currentProject",
                                label: "Current project",
                                children: [
                                  arrangementsTree,
                                  patternsTree,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

TreeViewItemModel getMarkersItem(
    {PatternModel? pattern, required void Function(ID key) onClick}) {
  final timeSignatureChanges = pattern!.timeSignatureChanges;

  return TreeViewItemModel(
    key: "markers",
    label: "Time markers",
    children: timeSignatureChanges
        .map(
          (change) => TreeViewItemModel(
            key: change.id,
            label: change.timeSignature.toDisplayString(),
            onClick: () {
              onClick(change.id);
            },
          ),
        )
        .toList(),
  );
}
