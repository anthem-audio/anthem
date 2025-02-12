/*
  Copyright (C) 2023 - 2025 Joshua Wade

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
import 'package:anthem/commands/project_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ProjectController {
  ProjectModel project;
  ProjectViewModel viewModel;

  ProjectController(this.project, this.viewModel);

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
    project.setSelectedDetailView(detailView);
    project.isDetailViewSelected = isVisible;
  }

  void setActiveGeneratorID(Id id) {
    project.activeInstrumentID = id;
  }

  Id addPattern([String? name]) {
    if (name == null) {
      final patterns = project.sequence.patterns.nonObservableInner;
      var patternNumber = patterns.length;

      final existingNames = patterns.values.map((pattern) => pattern.name);

      do {
        patternNumber++;
        name = 'Pattern $patternNumber';
      } while (existingNames.contains(name));
    }

    final patternModel = PatternModel.create(name: name);

    project.execute(
      AddPatternCommand(
        pattern: patternModel,
        index: project.sequence.patternOrder.length,
      ),
    );

    project.sequence.setActivePattern(patternModel.id);

    return patternModel.id;
  }

  void addArrangement([String? name]) {
    if (name == null) {
      final arrangements = project.sequence.arrangements.nonObservableInner;
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

    project.sequence.setActiveArrangement(command.arrangementID);
  }

  void onShortcut(LogicalKeySet shortcut) {
    // Undo
    if (shortcut.matches(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ))) {
      undo();
    }
    // Redo
    else if (shortcut.matches(LogicalKeySet(
            LogicalKeyboardKey.control, LogicalKeyboardKey.keyY)) ||
        shortcut.matches(LogicalKeySet(LogicalKeyboardKey.control,
            LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ))) {
      redo();
    }
  }

  void setHintText(String text) {
    viewModel.hintText = text;
  }

  void clearHintText() {
    viewModel.hintText = '';
  }

  void addGenerator({
    required NodeModel node,
    required String name,
    required GeneratorType generatorType,
    required Color color,
  }) {
    final id = getId();

    project.execute(
      AddGeneratorCommand(
        generatorId: id,
        node: node,
        name: name,
        generatorType: generatorType,
        color: color,
      ),
    );

    if (generatorType == GeneratorType.instrument) {
      project.activeInstrumentID = id;
    } else if (generatorType == GeneratorType.automation) {
      project.activeAutomationGeneratorID = id;
    }
  }

  void addVst3Generator() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a plugin (VST3)',
      allowedExtensions: ['vst3'],
      initialDirectory: 'C:\\Program Files\\Common Files\\VST3',
    );

    final path = result?.files[0].path;

    if (path == null) return;

    // addGenerator(
    //   name: 'Instrument ${(Random()).nextInt(100).toString()}',
    //   generatorType: GeneratorType.instrument,
    //   color: getColor(),
    //   pluginPath: path,
    // );
  }

  void removeGenerator(Id generatorID) {
    project.execute(
      RemoveGeneratorCommand(
        project: project,
        generator: project.generators[generatorID]!,
      ),
    );
  }
}

var nextHue = 0.0;

Color getColor() {
  final color = HSLColor.fromAHSL(1, nextHue, 0.33, 0.5).toColor();
  nextHue = (nextHue + 330) % 360;
  return color;
}
