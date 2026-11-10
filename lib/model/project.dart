/*
  Copyright (C) 2021 - 2026 Joshua Wade

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
import 'dart:convert';

import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/commands/project_command_controller.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem/engine_api/messages/messages.dart' as message_api;
import 'package:mobx/mobx.dart';
import 'package:path/path.dart' as path;

import 'processing_graph/processing_graph.dart';
import 'shared/hydratable.dart';

part 'project.g.dart';

enum ProjectLayoutKind { arrange, edit, mix }

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'Project',
  cppBehaviorClassIncludePath: 'modules/core/project.h',
)
class ProjectModel extends _ProjectModel
    with _$ProjectModel, _$ProjectModelAnthemModelMixin {
  late final ProjectEntityIdAllocator idAllocator = ProjectEntityIdAllocator(
    this,
  );

  ProjectModel() : super();

  ProjectModel.create([super._enginePathOverride]) : super.create() {
    final idAllocator = this.idAllocator;
    sequence = SequencerModel(idAllocator: idAllocator);
    processingGraph = ProcessingGraphModel.create(
      masterOutputNodeId: idAllocator.allocateId(),
    );
    hydrate();
    _init();

    final Map<Id, TrackModel> initTracks = {};
    final List<Id> initTrackOrder = [];
    final List<Id> initSendTrackOrder = [];

    void addTrack(TrackModel track, List<Id> orderList) {
      initTracks[track.id] = track;
      orderList.add(track.id);
    }

    for (var i = 1; i <= 1; i++) {
      final track = TrackModel(
        idAllocator: idAllocator,
        name: 'Track $i',
        color: .new(hue: 0, palette: .grayscale),
        type: .normal,
      );
      addTrack(track, initTrackOrder);
    }

    final masterTrack = TrackModel(
      idAllocator: idAllocator,
      name: 'Master',
      color: .new(hue: 0, palette: .grayscale),
      type: .normal,
    )..isMasterTrack = true;
    addTrack(masterTrack, initSendTrackOrder);

    tracks = AnthemObservableMap.of(initTracks);
    trackOrder = AnthemObservableList.of(initTrackOrder);
    sendTrackOrder = AnthemObservableList.of(initSendTrackOrder);

    for (final trackId in initTrackOrder.followedBy(initSendTrackOrder)) {
      initTracks[trackId]!.createAndRegisterNodes(
        this,
        idAllocator,
        isSendTrack: initSendTrackOrder.contains(trackId),
      );
    }

    final masterOutputPortId = processingGraph
        .getMasterOutputNode()
        .audioInputPorts
        .first
        .id;
    final masterTrackProcessing = masterTrack.requireProcessing;
    for (final trackId in initTrackOrder.followedBy(initSendTrackOrder)) {
      final track = initTracks[trackId]!;
      final processing = track.requireProcessing;
      final destinationNodeId = track.isMasterTrack
          ? processingGraph.masterOutputNodeId
          : masterTrackProcessing.utilityNodeId!;
      final destinationPortId = track.isMasterTrack
          ? masterOutputPortId
          : UtilityProcessorModel.audioInputPortId;

      processingGraph.addConnection(
        NodeConnectionModel(
          idAllocator: idAllocator,
          sourceNodeId: processing.audioOutputNodeId,
          sourcePortId: processing.audioOutputPortId,
          destinationNodeId: destinationNodeId,
          destinationPortId: destinationPortId,
          dataType: NodePortDataType.audio,
        ),
      );
    }
  }

  /// Restores persistent content with an optional runtime engine executable.
  /// The executable path is never read from or written to the project file.
  ///
  /// Note: when loading a project saved by an older version of Anthem, its JSON
  /// must already have been migrated to the current project file format before
  /// calling this constructor.
  /// See `lib/logic/project_file/migrations/migrate_project_json.dart`.
  factory ProjectModel.fromJson(
    Map<String, dynamic> json, {
    String? enginePathOverride,
  }) {
    final project = _$ProjectModelAnthemModelMixin.fromJson(json)
      // This is the top model in the tree. setParentPropertiesOnChildren will not
      // work correctly if we don't set this.
      ..isTopLevelModel = true
      .._enginePathOverride = enginePathOverride;
    project.hydrate();
    project._init();
    return project;
  }

  void _init() {
    // Normally we rely on the fact that this will always be put in the field of
    // another model, which will call setParentPropertiesOnChildren. Since this
    // is the top level, we need to call it ourselves.
    setParentPropertiesOnChildren();

    // We need to notify the engine when a track is removed so it can clean up
    // any compiled sequences for this channel.
    onChange(
      // This filter matches against removals from the tracks map.
      (b) => b.tracks().anyValue(bindKeyTo: 'trackId').filterByChangeType([
        ModelFilterChangeType.mapRemove,
      ]),
      (_, bindings) {
        if (!engine.isRunning) {
          return;
        }

        final trackId = bindings.get<Id>('trackId');
        engine.sequencerApi.cleanUpTrack(trackId);
      },
    );
  }
}

abstract class _ProjectModel extends Hydratable with Store, AnthemModelBase {
  /// Represents information about the sequenced content in the project, such as
  /// the arrangement and patterns, and their content.
  late SequencerModel sequence;

  /// Represents the processing graph for the project. This is used to route
  /// audio, control and notes between processors, and to eventually route the
  /// resulting audio to the audio output device.
  late ProcessingGraphModel processingGraph;

  /// Serialized asset-reference manifest read from a project document.
  /// Live ownership belongs to ProjectStorage.projectFiles. Save preparation
  /// writes a fresh manifest into the captured document JSON.
  @hideFromCpp
  String fileRetentions = '{}';

  /// The version of Anthem that last saved this project file.
  @hideFromCpp
  String savedInSoftwareVersion = currentProjectFileSoftwareVersion;

  /// ID of the master output node in the processing graph. Audio that is routed
  /// to this node is sent to the audio output device.
  @anthemObservable
  @hideFromSerialization
  int? masterOutputNodeId;

  @anthemObservable
  AnthemObservableMap<Id, TrackModel> tracks = AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<Id> trackOrder = AnthemObservableList();

  @anthemObservable
  AnthemObservableList<Id> sendTrackOrder = AnthemObservableList();

  @hideFromCpp
  int idCounter = 0;

  Id allocateId() {
    return idCounter++;
  }

  /// Globally unique ID for the project file.
  @hideFromCpp
  ProjectId id = getProjectId();

  /// The file path of the project.
  @anthemObservable
  @hideFromSerialization
  String? filePath;

  String get name {
    if (filePath == null) {
      return 'New Project';
    }

    return path.basenameWithoutExtension(filePath!);
  }

  /// Tracks whether or not the project has been saved.
  ///
  /// If false, the project has either never been saved, or otherwise has been
  /// saved and not modified since then.
  @anthemObservable
  @hideFromSerialization
  bool isDirty = false;

  @anthemObservable
  @hide
  bool isDetailViewOpen = true;

  @anthemObservable
  @hide
  bool isProjectExplorerOpen = false;

  // Visual layout flags

  @anthemObservable
  @hide
  bool isAutomationMatrixVisible = true;

  @anthemObservable
  @hide
  ProjectLayoutKind layout = ProjectLayoutKind.arrange;

  // Command execution and undo/redo.

  @hide
  late final ProjectCommandController _commandController;

  // Engine

  @hide
  final engineID = getEngineID();

  @hide
  late Engine engine = Engine(
    engineID,
    this as ProjectModel,
    enginePathOverride: _enginePathOverride,
  );

  @anthemObservable
  @hide
  var engineState = EngineState.stopped;

  @hide
  late final VisualizationProvider visualizationProvider;

  // This method is used for deserialization and so doesn't create new child
  // models.
  _ProjectModel() : _enginePathOverride = null, super() {
    // This is the top model in the tree. setParentPropertiesOnChildren will not
    // work correctly if we don't set this.
    isTopLevelModel = true;

    _commandController = ProjectCommandController(this as ProjectModel);
  }

  @hide
  void Function(ModelChangeEvent)? _fieldChangedListener;

  @hide
  // Assigned during construction/deserialization before the lazy engine exists.
  String? _enginePathOverride;

  _ProjectModel.create([this._enginePathOverride]) : super() {
    // This is the top model in the tree. setParentPropertiesOnChildren will not
    // work correctly if we don't set this.
    isTopLevelModel = true;

    _commandController = ProjectCommandController(this as ProjectModel);
  }

  @hide
  var _modelSyncCompleter = Completer<void>();

  /// Waits for the model to be synced with the engine. If the model is already
  /// synced, this will return immediately.
  Future<void> waitForFirstSync() => _modelSyncCompleter.future;

  /// This function is run after deserialization. It allows us to do some setup
  /// that the deserialization step can't do for us.
  void hydrate() {
    engine.engineStateStream.listen((state) {
      (this as ProjectModel).engineState = state;

      if (state == EngineState.stopped) {
        handleEngineStopped();
      }
    });

    visualizationProvider = VisualizationProvider(this as ProjectModel);

    isHydrated = true;
  }

  /// Initializes the engine model while the engine is still in the startup
  /// phase.
  Future<message_api.ModelInitResponse> initializeEngine() {
    _attachModelChangeListener();

    return engine.modelSyncApi.initModel(
      jsonEncode(
        (this as _$ProjectModelAnthemModelMixin).toJson(
          forEngine: true,
          forProjectFile: false,
        ),
      ),
    );
  }

  /// Completes the first-sync future after the engine has acknowledged the
  /// initial model.
  void completeFirstEngineSync() {
    if (!_modelSyncCompleter.isCompleted) {
      _modelSyncCompleter.complete();
    }
  }

  /// Cleans up model-side engine sync state after the engine process stops.
  void handleEngineStopped() {
    final hadSyncState =
        _fieldChangedListener != null || _modelSyncCompleter.isCompleted;

    // Make sure the engine isn't playing when it starts again.
    sequence.isPlaying = false;

    if (_fieldChangedListener != null) {
      // Unhook the model change stream from the engine.
      (this as AnthemModelBase).removeRawFieldChangedListener(
        _fieldChangedListener!,
      );
      _fieldChangedListener = null;
    }

    if (hadSyncState) {
      _modelSyncCompleter = Completer();
    }
  }

  /// Attaches a listener for model state change events, and send them to the
  /// engine.
  ///
  /// This is used to keep the engine in sync with the UI model state. The state
  /// change events are created by generated code, and also processed by
  /// generated code in the engine.
  void _attachModelChangeListener() {
    if (_fieldChangedListener != null) return;

    _fieldChangedListener = (change) {
      if (!change.sendToEngine ||
          (engine.engineState != EngineState.starting && !engine.isRunning)) {
        return;
      }

      String? serializeMapKey(dynamic key) {
        return switch (key) {
          null => null,
          int i => '$i',
          double d => '$d',
          String s => '"$s"',
          bool b => '$b',
          _ => throw AssertionError('Invalid map key type'),
        };
      }

      // Values will already be in JSON format, but we need to convert to
      // string. This is just like the above but with the addition of
      // Map<String, dynamic> and List<dynamic>.
      String serializeValue(dynamic value) {
        return switch (value) {
          null => 'null',
          int i => '$i',
          double d => '$d',
          String s => '"$s"',
          bool b => '$b',
          Map<String, dynamic> m => jsonEncode(m),
          List<dynamic> l => jsonEncode(l),
          _ => throw AssertionError('Invalid value type: ${value.runtimeType}'),
        };
      }

      final convertedAccesses = change.fieldAccessors.map((access) {
        return message_api.FieldAccess(
          fieldName: access.fieldName,
          fieldType: switch (access.fieldType) {
            FieldType.raw => message_api.FieldType.raw,
            FieldType.list => message_api.FieldType.list,
            FieldType.map => message_api.FieldType.map,
          },
          listIndex: access.index,
          serializedMapKey: serializeMapKey(access.key),
        );
      }).toList();

      engine.modelSyncApi.updateModel(
        updateKind: switch (change.operation) {
          RawFieldUpdate() ||
          ListUpdate() ||
          MapPut() => message_api.FieldUpdateKind.set,
          ListInsert() => message_api.FieldUpdateKind.add,
          ListRemove() || MapRemove() => message_api.FieldUpdateKind.remove,
        },
        fieldAccesses: convertedAccesses,
        serializedValue: switch (change.operation) {
          RawFieldUpdate op => serializeValue(op.newValueSerialized),
          ListInsert op => serializeValue(op.valueSerialized),
          ListUpdate op => serializeValue(op.newValueSerialized),
          MapPut op => serializeValue(op.newValueSerialized),
          _ => null,
        },
      );
    };

    // Hook up the model change stream to the engine
    (this as AnthemModelBase).addRawFieldChangedListener(
      _fieldChangedListener!,
    );
  }

  /// Executes a command and optionally keeps it for undo and redo.
  ///
  /// Ordinary commands run immediately. Commands that need file I/O are
  /// awaited before later command operations run. A command executed with
  /// [push] set to false is disposed after execution.
  Future<void> execute(Command command, {bool push = true}) =>
      _commandController.execute(command, push: push);

  /// Adds an already applied command to history, or executes it first.
  Future<void> push(Command command, {bool execute = false}) =>
      _commandController.push(command, execute: execute);

  /// Undoes the last command, waiting for any required state capture.
  Future<void> undo() => _commandController.undo();

  /// Redoes the next command, waiting for any required state capture.
  Future<void> redo() => _commandController.redo();

  /// Starts grouping commands into one undo/redo action.
  Future<void> startUndoGroup() => _commandController.startUndoGroup();

  /// Transfers the commands in the open group to the undo/redo history.
  Future<void> commitUndoGroup() => _commandController.commitUndoGroup();

  /// Waits for queued command work, including failed operations, to finish.
  Future<void> waitForPendingCommands() =>
      _commandController.waitForPendingCommands();

  @hide
  Future<void>? _disposeFuture;

  /// Finishes pending commands, stops the engine, and releases model resources.
  ///
  /// Concurrent calls share the same future. If cleanup fails, a later call can
  /// retry it. Project storage must stay open until disposal completes.
  Future<void> dispose() => _disposeFuture ??= _dispose().catchError((
    Object error,
    StackTrace stack,
  ) {
    _disposeFuture = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _dispose() async {
    await _commandController.close();
    await engine.dispose();
    sequence.dispose();
    visualizationProvider.dispose();
  }
}
