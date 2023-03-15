/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/commands/arrangement_commands.dart';
import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';

class ProjectController {
  ProjectModel project;

  ProjectController(this.project);

  void journalStartEntry() {
    project.startJournalPage();
  }

  void journalCommitEntry() {
    project.commitJournalPage();
  }

  void undo() {
    project.undo();
  }

  void redo() {
    project.redo();
  }

  void setActiveDetailView(bool isVisible, [DetailViewKind? detailView]) {
    project.selectedDetailView = detailView;
    project.isDetailViewSelected = isVisible;
  }

  void setActiveGeneratorID(ID id) {
    project.activeGeneratorID = id;
  }

  ID addPattern([String? name]) {
    if (name == null) {
      final patterns = project.song.patterns.nonObservableInner;
      var patternNumber = patterns.length;

      final existingNames = patterns.values.map((pattern) => pattern.name);

      do {
        patternNumber++;
        name = 'Pattern $patternNumber';
      } while (existingNames.contains(name));
    }

    final patternModel = PatternModel.create(name: name, project: project);

    project.execute(
      AddPatternCommand(
        project: project,
        pattern: patternModel,
        index: project.song.patternOrder.length,
      ),
    );

    project.song.setActivePattern(patternModel.id);

    return patternModel.id;
  }

  void addArrangement([String? name]) {
    if (name == null) {
      final arrangements = project.song.arrangements.nonObservableInner;
      var arrangementNumber = arrangements.length;

      final existingNames = arrangements.values.map((pattern) => pattern.name);

      do {
        arrangementNumber++;
        name = 'Arrangement $arrangementNumber';
      } while (existingNames.contains(name));
    }

    final command = AddArrangementCommand(
      project: project,
      arrangementName: name,
    );

    project.execute(command);

    project.song.setActiveArrangement(command.arrangementID);
  }
}
