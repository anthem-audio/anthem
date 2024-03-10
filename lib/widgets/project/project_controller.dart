/*
  Copyright (C) 2023 - 2024 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem/widgets/project/typing_keyboard_piano_handler.dart';
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
    project.selectedDetailView = detailView;
    project.isDetailViewSelected = isVisible;
  }

  void setActiveGeneratorID(ID id) {
    project.activeInstrumentID = id;
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

  bool onKey(KeyEvent event) {
    if (event is KeyRepeatEvent) return false;

    final key = event.logicalKey;

    if (viewModel.keyboardPianoEnabled && isTypingPianoKey(key)) {
      final note = getMidiNoteFromKeyboardKey(key)!;

      if (event is KeyDownEvent) {
        project.engine.projectApi.noteOn(
          note: note,
          editId: project
              .song.arrangements[project.song.activeArrangementID]!.editPointer,
        );
      } else {
        project.engine.projectApi.noteOff(
          note: note,
          editId: project
              .song.arrangements[project.song.activeArrangementID]!.editPointer,
        );
      }

      return true;
    }

    return false;
  }

  void setHintText(String text) {
    viewModel.hintText = text;
  }

  void clearHintText() {
    viewModel.hintText = '';
  }

  void addGenerator({
    required String? processorId,
    required String name,
    required GeneratorType generatorType,
    required Color color,
  }) {
    final id = getID();

    project.execute(
      AddGeneratorCommand(
        generatorId: id,
        processorId: processorId,
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
}

var nextHue = 0.0;

Color getColor() {
  final color = HSLColor.fromAHSL(1, nextHue, 0.33, 0.5).toColor();
  nextHue = (nextHue + 330) % 360;
  return color;
}
