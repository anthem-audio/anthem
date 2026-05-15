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
    show
        ProcessingGraphNodeInitializationResult,
        ProcessingGraphNodePortConfiguration,
        ProcessingGraphPortConfiguration;
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/devices/device_port_defaults.dart';
import 'package:anthem/logic/live_event_manager.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
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

        _applyNodePortConfigurations(initialization.results);

        await project.engine.processingGraphApi.publish();
      }
    } finally {
      _isPublishingProcessingGraph = false;
      _pendingProcessingGraphPublishCount = 0;
      _processingGraphPublishFuture = null;
    }
  }

  void _applyNodePortConfigurations(
    List<ProcessingGraphNodeInitializationResult> results,
  ) {
    final affectedTrackIds = <Id>{};

    for (final result in results) {
      final portConfiguration = result.portConfiguration;
      if (!result.success || portConfiguration == null) {
        continue;
      }

      final didChange = _applyNodePortConfiguration(
        result.nodeId,
        portConfiguration,
      );
      if (!didChange) {
        continue;
      }

      affectedTrackIds.addAll(_updateDeviceDefaultsForNode(result.nodeId));
    }

    if (affectedTrackIds.isEmpty) {
      return;
    }

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    for (final trackId in affectedTrackIds) {
      serviceRegistry.deviceController.rebuildTrackDeviceRouting(trackId);
      serviceRegistry.trackController.rerouteTracks([trackId]);
    }
  }

  bool _applyNodePortConfiguration(
    Id nodeId,
    ProcessingGraphNodePortConfiguration portConfiguration,
  ) {
    final node = project.processingGraph.nodes[nodeId];
    if (node == null) {
      return false;
    }

    final portGroups =
        <
          ({
            AnthemObservableList<NodePortModel> currentPorts,
            List<ProcessingGraphPortConfiguration> newPortConfigurations,
            NodePortDataType dataType,
          })
        >[
          (
            currentPorts: node.audioInputPorts,
            newPortConfigurations: portConfiguration.audioInputPorts,
            dataType: .audio,
          ),
          (
            currentPorts: node.audioOutputPorts,
            newPortConfigurations: portConfiguration.audioOutputPorts,
            dataType: .audio,
          ),
          (
            currentPorts: node.eventInputPorts,
            newPortConfigurations: portConfiguration.eventInputPorts,
            dataType: .event,
          ),
          (
            currentPorts: node.eventOutputPorts,
            newPortConfigurations: portConfiguration.eventOutputPorts,
            dataType: .event,
          ),
          (
            currentPorts: node.controlInputPorts,
            newPortConfigurations: portConfiguration.controlInputPorts,
            dataType: .control,
          ),
          (
            currentPorts: node.controlOutputPorts,
            newPortConfigurations: portConfiguration.controlOutputPorts,
            dataType: .control,
          ),
        ];

    final didChange = portGroups.any(
      (group) => !_portListMatches(
        group.currentPorts,
        group.newPortConfigurations,
        group.dataType,
      ),
    );

    if (!didChange) {
      return false;
    }

    for (final portGroup in portGroups) {
      _removeConnectionsForUnconfiguredPorts(
        portGroup.currentPorts,
        portGroup.newPortConfigurations,
      );

      _replacePorts(
        portGroup.currentPorts,
        portGroup.newPortConfigurations,
        portGroup.dataType,
        nodeId,
      );
    }

    return true;
  }

  bool _portListMatches(
    AnthemObservableList<NodePortModel> currentPorts,
    List<ProcessingGraphPortConfiguration> configuredPorts,
    NodePortDataType dataType,
  ) {
    // This compares only the processor-declared port shape. Runtime state like
    // connections and parameter values is preserved when ports are replaced.
    if (currentPorts.length != configuredPorts.length) {
      return false;
    }

    for (var i = 0; i < currentPorts.length; i++) {
      final currentPort = currentPorts[i];
      final configuredPort = configuredPorts[i];
      final currentParameterConfig = currentPort.config.parameterConfig;
      if (currentPort.id != configuredPort.id ||
          currentPort.config.dataType != dataType ||
          currentPort.config.name != configuredPort.name ||
          currentPort.config.channelCount != configuredPort.channelCount ||
          currentParameterConfig?.id !=
              _parameterConfigIdForPort(configuredPort) ||
          currentParameterConfig?.defaultValue !=
              configuredPort.parameterDefaultValue) {
        return false;
      }
    }

    return true;
  }

  void _removeConnectionsForPorts(Iterable<NodePortModel> ports) {
    final connectionIds = <Id>{
      for (final port in ports)
        for (final connectionId in port.connections) connectionId,
    };

    for (final connectionId in connectionIds) {
      if (project.processingGraph.connections[connectionId] != null) {
        project.processingGraph.removeConnection(connectionId);
      }
    }
  }

  void _removeConnectionsForUnconfiguredPorts(
    AnthemObservableList<NodePortModel> currentPorts,
    List<ProcessingGraphPortConfiguration> configuredPorts,
  ) {
    final configuredPortIds = {for (final port in configuredPorts) port.id};

    _removeConnectionsForPorts(
      currentPorts.where((port) => !configuredPortIds.contains(port.id)),
    );
  }

  int? _parameterConfigIdForPort(ProcessingGraphPortConfiguration port) {
    return port.parameterDefaultValue == null ? null : port.id;
  }

  ParameterConfigModel? _parameterConfigForPort(
    ProcessingGraphPortConfiguration port,
  ) {
    final defaultValue = port.parameterDefaultValue;
    if (defaultValue == null) {
      return null;
    }

    return ParameterConfigModel(id: port.id, defaultValue: defaultValue);
  }

  void _replacePorts(
    AnthemObservableList<NodePortModel> target,
    List<ProcessingGraphPortConfiguration> configuredPorts,
    NodePortDataType dataType,
    Id nodeId,
  ) {
    final currentPortsById = {for (final port in target) port.id: port};

    target
      ..clear()
      ..addAll(
        configuredPorts.map((port) {
          final replacementPort = NodePortModel(
            nodeId: nodeId,
            id: port.id,
            config: NodePortConfigModel(
              dataType: dataType,
              name: port.name,
              channelCount: port.channelCount,
              parameterConfig: _parameterConfigForPort(port),
            ),
          );

          final currentPort = currentPortsById[port.id];
          if (currentPort != null) {
            replacementPort.connections.addAll(currentPort.connections);
            if (replacementPort.config.parameterConfig != null) {
              replacementPort.parameterValue =
                  currentPort.parameterValue ?? replacementPort.parameterValue;
            }
          }

          return replacementPort;
        }),
      );
  }

  Iterable<Id> _updateDeviceDefaultsForNode(Id nodeId) sync* {
    final devicePortDefaults = DevicePortDefaults(project.processingGraph);

    for (final track in project.tracks.values) {
      for (final device in track.devices) {
        if (!device.nodeIds.contains(nodeId)) {
          continue;
        }

        devicePortDefaults.refreshDeviceDefaultPorts(device);
        yield track.id;
      }
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
