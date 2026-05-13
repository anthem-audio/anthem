/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/live_event_manager.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ProjectController {
  ProjectModel project;
  ProjectViewModel viewModel;
  late final LiveEventManager liveEventManager = LiveEventManager(project);

  bool _isPublishingProcessingGraph = false;
  int _pendingProcessingGraphPublishCount = 0;
  Future<void>? _processingGraphPublishFuture;

  ProjectController(this.project, this.viewModel);

  void undo() {
    project.undo();
  }

  void redo() {
    project.redo();
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
    project.sequence.activeTransportSequenceID = command.arrangementID;
  }

  void onShortcut(LogicalKeySet shortcut) {
    // Undo
    if (shortcut.matches(
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ),
    )) {
      undo();
    }
    // Redo
    else if (shortcut.matches(
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY),
        ) ||
        shortcut.matches(
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyZ,
          ),
        )) {
      redo();
    }
    // Play / stop
    else if (shortcut.matches(LogicalKeySet(LogicalKeyboardKey.space))) {
      togglePlayback();
    }
  }

  void togglePlayback() {
    if (project.engineState == EngineState.running) {
      project.sequence.isPlaying = !project.sequence.isPlaying;
    }
  }

  Future<void> publishProcessingGraph() {
    if (_isPublishingProcessingGraph) {
      _pendingProcessingGraphPublishCount++;
      return _processingGraphPublishFuture ?? Future<void>.value();
    }

    _pendingProcessingGraphPublishCount = 1;
    _processingGraphPublishFuture = _runProcessingGraphPublishQueue();
    return _processingGraphPublishFuture!;
  }

  Future<void> _runProcessingGraphPublishQueue() async {
    _isPublishingProcessingGraph = true;

    try {
      while (_pendingProcessingGraphPublishCount > 0) {
        _pendingProcessingGraphPublishCount--;

        final initialization = await project.engine.processingGraphApi
            .initializeNodes();

        if (!initialization.didInitialize) {
          break;
        }

        await project.engine.processingGraphApi.publish();
      }
    } finally {
      _isPublishingProcessingGraph = false;
      _pendingProcessingGraphPublishCount = 0;
      _processingGraphPublishFuture = null;
    }
  }

  void setActiveArrangement(Id? id) {
    project.sequence.setActiveArrangement(id);
    _updateTransportSequenceID(id);
  }

  void setActiveEditor({required EditorKind editor}) {
    viewModel.selectedEditor = editor;

    viewModel.activePanel = switch (editor) {
      .detail => .pianoRoll,
      .automation => .automationEditor,
      .deviceRack => .deviceRack,
      .mixer => .mixer,
    };
  }

  void setActivePattern(Id? id) {
    project.sequence.setActivePattern(id);
    _updateTransportSequenceID(id);
  }

  void openPatternInPianoRoll(Id patternID) {
    if (!project.sequence.patterns.containsKey(patternID)) {
      return;
    }

    setActiveEditor(editor: EditorKind.detail);
    project.sequence.setActivePattern(patternID);
  }

  void _updateTransportSequenceID(Id? id) {
    project.sequence.activeTransportSequenceID = id;
    if (id != null) {
      project.visualizationProvider.overrideValue(
        id: 'playhead_sequence_id',
        value: id,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  /// Closes the project.
  ///
  /// Returns true if the project was closed, false if the close was cancelled.
  Future<bool> close() {
    final dialogController = ServiceRegistry.dialogController;
    final mainWindowController = ServiceRegistry.mainWindowController;

    final completer = Completer<bool>();

    if (project.isDirty) {
      dialogController.showTextDialog(
        title: 'Unsaved Changes',
        text:
            'The project "${project.name}" has unsaved changes.\n\n'
            'Do you want to save before closing?',
        onDismiss: () {
          completer.complete(false);
        },
        buttons: [
          DialogButton(text: 'Cancel', isDismissive: true),
          DialogButton(
            text: "Don't Save",
            onPress: () {
              mainWindowController.closeProjectWithoutSaving(project.id);
              completer.complete(true);
            },
          ),
          DialogButton(
            text: 'Save',
            onPress: () async {
              final result = await mainWindowController.saveProject(
                project.id,
                false,
                dialogController: dialogController,
              );
              if (result) {
                mainWindowController.closeProjectWithoutSaving(project.id);
              }
              completer.complete(result);
            },
          ),
        ],
      );
    } else {
      mainWindowController.closeProjectWithoutSaving(project.id);
      completer.complete(true);
    }

    return completer.future;
  }
}
