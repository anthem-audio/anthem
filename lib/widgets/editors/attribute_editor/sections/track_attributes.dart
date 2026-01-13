/*
  Copyright (C) 2026 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/hint/hint.dart';
import 'package:anthem/widgets/basic/text_box_controlled.dart';
import 'package:anthem/widgets/editors/attribute_editor/attribute_editor_helpers.dart';
import 'package:anthem/widgets/editors/attribute_editor/attribute_group.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class TrackAttributes extends StatefulObserverWidget {
  const TrackAttributes({super.key});

  @override
  State<TrackAttributes> createState() => _TrackAttributesState();
}

class _TrackAttributesState extends State<TrackAttributes> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final arrangerViewModel = serviceRegistry.arrangerViewModel;
    final projectController = serviceRegistry.projectController;

    if (arrangerViewModel.selectedTracks.isEmpty) {
      return SizedBox();
    }

    final selectedTrackIds = arrangerViewModel.selectedTracks;

    //
    // Track name
    //

    final trackName = getStringAttributeValue(
      selectedTrackIds.map((id) => project.tracks[id]!.name),
    );

    void setTrackName(String newName) {
      project.startJournalPage();
      for (final id in selectedTrackIds) {
        projectController.setTrackName(id, newName);
      }
      project.commitJournalPage();
    }

    return AttributeGroup(
      title: selectedTrackIds.length == 1
          ? 'Track'
          : 'Tracks (${selectedTrackIds.length})',
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 4,
        children: [
          Row(
            spacing: 4,
            children: [
              // Container(width: 20, height: 20, color: color),
              Expanded(
                child: Hint(
                  hint: [.new('click', 'Set the track name')],
                  child: ControlledTextBox(
                    text: trackName,
                    onChange: setTrackName,
                    textAlign: .end,
                    height: 20,
                  ),
                ),
              ),
            ],
          ),
          // _spacer(),
        ],
      ),
    );
  }
}

// Widget _spacer() => ColoredBox(
//   color: AnthemTheme.panel.border,
//   child: const SizedBox(height: 1),
// );
