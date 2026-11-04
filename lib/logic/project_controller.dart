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
import 'package:anthem/engine_api/messages/messages.dart'
    show ProcessingGraphNodeInitializationResult;
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/devices/device_port_defaults.dart';
import 'package:anthem/logic/live_event_manager.dart';
import 'package:anthem/logic/parameter_controller.dart';
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

  /// Shared by the tempo control and history buttons so Undo/Redo can cancel
  /// tapping before outside-click cancellation would allow history to change.
  final Object tempoTapRegionGroupId = Object();

  /// Installed while tapping. Returns true if a pending tempo edit was cancelled.
  bool Function()? cancelTempoTap;

  bool _needsProcessingGraphPublish = false;
  Future<void>? _processingGraphPublishFuture;

  ProjectController(this.project, this.viewModel);

  Future<void> undo() {
    if (cancelTempoTap?.call() ?? false) return Future.value();
    return project.undo();
  }

  Future<void> redo() {
    if (cancelTempoTap?.call() ?? false) return Future.value();
    return project.redo();
  }

  bool onShortcut(LogicalKeySet shortcut) {
    // Undo
    if (shortcut.matches(
      LogicalKeySet(primaryModifierKey, LogicalKeyboardKey.keyZ),
    )) {
      undo();
      return true;
    }
    // Redo
    else if (shortcut.matches(
          LogicalKeySet(primaryModifierKey, LogicalKeyboardKey.keyY),
        ) ||
        shortcut.matches(
          LogicalKeySet(
            primaryModifierKey,
            LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyZ,
          ),
        )) {
      redo();
      return true;
    }
    // Play / stop
    else if (shortcut.matches(LogicalKeySet(LogicalKeyboardKey.space))) {
      togglePlayback();
      return true;
    }

    return false;
  }

  void togglePlayback() {
    if (project.engineState == EngineState.running &&
        project.engine.isAudioReady) {
      project.sequence.isPlaying = !project.sequence.isPlaying;
    }
  }

  Future<void> publishProcessingGraph() {
    _needsProcessingGraphPublish = true;

    return _processingGraphPublishFuture ??=
        _runProcessingGraphPublishQueue(forRender: false).whenComplete(() {
          _processingGraphPublishFuture = null;
        });
  }

  Future<void> publishProcessingGraphForRender() async {
    _needsProcessingGraphPublish = true;

    await _runProcessingGraphPublishQueue(forRender: true);
  }

  Future<void> _runProcessingGraphPublishQueue({
    required bool forRender,
  }) async {
    try {
      while (_needsProcessingGraphPublish) {
        _needsProcessingGraphPublish = false;

        final initialization = forRender
            ? await project.engine.processingGraphApi.initializeNodesForRender()
            : await project.engine.processingGraphApi.initializeNodes();

        if (!initialization.didInitialize) {
          break;
        }

        _applyNodePortConfigurations(initialization.results);

        if (forRender) {
          await project.engine.processingGraphApi.publishForRender();
        } else {
          await project.engine.processingGraphApi.publish();
        }
      }
    } finally {
      _needsProcessingGraphPublish = false;
    }
  }

  void _applyNodePortConfigurations(
    List<ProcessingGraphNodeInitializationResult> results,
  ) {
    final affectedTrackIds = <Id>{};

    for (final result in results) {
      final node = project.processingGraph.nodes[result.nodeId];
      if (node == null) continue;
      if (!result.success) {
        node.markInitializationFailed();
        continue;
      }

      final portConfiguration = result.portConfiguration;

      if (portConfiguration != null) {
        final routingChanged = node.applyPortConfiguration(portConfiguration);
        if (routingChanged) {
          affectedTrackIds.addAll(_updateDeviceDefaultsForNode(result.nodeId));
        }
      }

      applyReportedParameterValues(node, result.parameterValues);
      node.markInitialized();
    }

    if (affectedTrackIds.isEmpty) {
      return;
    }

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    for (final trackId in affectedTrackIds) {
      serviceRegistry.deviceController.rebuildTrackDeviceRouting(trackId);
    }
  }

  Iterable<Id> _updateDeviceDefaultsForNode(Id nodeId) sync* {
    final devicePortDefaults = DevicePortDefaults(project.processingGraph);

    for (final track in project.tracks.values) {
      if (!track.hasProcessing) {
        continue;
      }
      final processing = track.requireProcessing;

      for (final device in processing.devices) {
        if (!device.nodeIds.contains(nodeId)) {
          continue;
        }

        devicePortDefaults.refreshDeviceDefaultPorts(device);
        yield track.id;
      }
    }
  }

  void setActiveEditor({required EditorKind editor}) {
    viewModel.selectedEditor = editor;

    viewModel.activePanel = switch (editor) {
      .pianoRoll => .pianoRoll,
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

    setActiveEditor(editor: EditorKind.pianoRoll);
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
  Future<bool> close() async {
    final dialogController = ServiceRegistry.dialogController;
    final mainWindowController = ServiceRegistry.mainWindowController;

    final completer = Completer<bool>();

    Future<void> finishClosing({required bool save}) async {
      try {
        var shouldClose = true;
        if (save) {
          shouldClose = await mainWindowController.saveProject(
            project.id,
            false,
            dialogController: dialogController,
          );
          if (project.isDirty) {
            shouldClose = false;
          }
        }
        if (shouldClose) {
          await mainWindowController.closeProjectWithoutSaving(project.id);
        }
        completer.complete(shouldClose);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    if (project.isDirty) {
      dialogController.showMarkdownDialog(
        title: 'Unsaved Changes',
        markdown:
            'The project "${escapeDialogMarkdown(project.name)}" has unsaved '
            'changes.\n\n'
            'Do you want to save before closing?',
        onDismiss: () {
          completer.complete(false);
        },
        buttons: [
          DialogButton(text: 'Cancel', isDismissive: true),
          DialogButton(
            text: "Don't Save",
            onPress: () => finishClosing(save: false),
          ),
          DialogButton(text: 'Save', onPress: () => finishClosing(save: true)),
        ],
      );
    } else {
      await mainWindowController.closeProjectWithoutSaving(project.id);
      completer.complete(true);
    }

    return completer.future;
  }
}
