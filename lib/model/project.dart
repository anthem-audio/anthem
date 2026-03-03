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
import 'package:anthem/logic/commands/command_stack.dart';
import 'package:anthem/logic/commands/journal_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem_codegen/include.dart';
import 'package:anthem/engine_api/messages/messages.dart' as message_api;
import 'package:mobx/mobx.dart';

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
  ProjectModel() : super();

  ProjectModel.create([super._enginePathOverride]) : super.create() {
    _init();

    final Map<Id, TrackModel> initTracks = {};
    final List<Id> initTrackOrder = [];
    final List<Id> initSendTrackOrder = [];

    for (var i = 1; i <= 1; i++) {
      final track = TrackModel(
        name: 'Track $i',
        color: AnthemColor.randomHue(),
        type: .instrument,
      );
      track.createAndRegisterNodes(this);
      initTracks[track.id] = track;
      initTrackOrder.add(track.id);
    }

    final masterTrack =
        TrackModel(name: 'Master', color: AnthemColor.randomHue(), type: .audio)
          ..isMasterTrack = true
          ..createAndRegisterNodes(this);
    initTracks[masterTrack.id] = masterTrack;
    initSendTrackOrder.add(masterTrack.id);

    tracks = AnthemObservableMap.of(initTracks);
    trackOrder = AnthemObservableList.of(initTrackOrder);
    sendTrackOrder = AnthemObservableList.of(initSendTrackOrder);
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final project = _$ProjectModelAnthemModelMixin.fromJson(json)
      // This is the top model in the tree. setParentPropertiesOnChildren will not
      // work correctly if we don't set this.
      ..isTopLevelModel = true;
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
      (b) => b.tracks.anyValue.filterByChangeType([
        ModelFilterChangeType.mapRemove,
      ]),
      (e) {
        if (!engine.isRunning) {
          return;
        }

        // Field accessors are:
        // 0: the tracks field
        // 1: accessing a value in the map by key
        final trackId = e.fieldAccessors[1].key as Id;
        engine.sequencerApi.cleanUpTrack(trackId);
      },
    );
  }
}

abstract class _ProjectModel extends Hydratable with Store, AnthemModelBase {
  /// Represents information about the sequenced content in the project, such as
  /// arrangements and patterns, and their content.
  late SequencerModel sequence;

  /// Represents the processing graph for the project. This is used to route
  /// audio, control and notes between processors, and to eventually route the
  /// resulting audio to the audio output device.
  late ProcessingGraphModel processingGraph;

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

  /// The ID of the project.
  @hideFromSerialization
  Id id = getId();

  /// The file path of the project.
  @anthemObservable
  @hideFromSerialization
  String? filePath;

  String get name {
    if (filePath == null) {
      return 'New Project';
    }

    return filePath!.split(RegExp('[/\\\\]')).last.split('.').first;
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

  // Undo / redo & etc

  @hide
  late final CommandStack _commandStack;

  @hide
  List<Command> _undoGroupAccumulator = [];

  @hide
  bool _undoGroupActive = false;

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

    _commandStack = CommandStack(this as ProjectModel);
  }

  @hide
  void Function(Iterable<FieldAccessor>, FieldOperation)? _fieldChangedListener;

  @hide
  final String? _enginePathOverride;

  _ProjectModel.create([this._enginePathOverride]) : super() {
    // This is the top model in the tree. setParentPropertiesOnChildren will not
    // work correctly if we don't set this.
    isTopLevelModel = true;

    _commandStack = CommandStack(this as ProjectModel);
    sequence = SequencerModel.create();
    processingGraph = ProcessingGraphModel();

    hydrate();
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

      if (state == EngineState.running) {
        _finishEngineStartup();
      }

      if (state == EngineState.stopped) {
        // Make sure the engine isn't playing when it starts again
        sequence.isPlaying = false;

        if (_fieldChangedListener != null) {
          // Unhook the model change stream from the engine
          (this as AnthemModelBase).removeRawFieldChangedListener(
            _fieldChangedListener!,
          );
          _fieldChangedListener = null;
        }
        _modelSyncCompleter = Completer();
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

  /// Finishes startup work after the engine has acknowledged the initial model.
  void _finishEngineStartup() {
    if (!_modelSyncCompleter.isCompleted) {
      _modelSyncCompleter.complete();
    }

    // The engine will receive the processing graph when we sync the model,
    // but it still needs to be compiled by the engine for use on the audio
    // thread, so we do that here.
    engine.processingGraphApi.compile();

    // We need to compile all arrangements for use in the audio thread.
    for (final arrangement in sequence.arrangements.values) {
      engine.sequencerApi.compileArrangement(arrangement.id);
    }

    // And same for patterns.
    for (final pattern in sequence.patterns.values) {
      engine.sequencerApi.compilePattern(pattern.id);
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

    _fieldChangedListener = (accesses, operation) {
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

      final convertedAccesses = accesses.map((access) {
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

      if (engine.engineState == EngineState.stopped) {
        return;
      }

      engine.modelSyncApi.updateModel(
        updateKind: switch (operation) {
          RawFieldUpdate() ||
          ListUpdate() ||
          MapPut() => message_api.FieldUpdateKind.set,
          ListInsert() => message_api.FieldUpdateKind.add,
          ListRemove() || MapRemove() => message_api.FieldUpdateKind.remove,
        },
        fieldAccesses: convertedAccesses,
        serializedValue: switch (operation) {
          RawFieldUpdate() => serializeValue(operation.newValueSerialized),
          ListInsert() => serializeValue(operation.valueSerialized),
          ListUpdate() => serializeValue(operation.newValueSerialized),
          MapPut() => serializeValue(operation.newValueSerialized),
          _ => null,
        },
      );
    };

    // Hook up the model change stream to the engine
    (this as AnthemModelBase).addRawFieldChangedListener(
      _fieldChangedListener!,
    );
  }

  /// Executes the given command on the project and pushes it to the undo/redo
  /// queue.
  void execute(Command command, {bool push = true}) {
    command.execute(this as ProjectModel);

    if (push) {
      if (_undoGroupActive) {
        _undoGroupAccumulator.add(command);
      } else {
        _commandStack.push(command);
      }
    }

    // If we receive an action that can be undone, then we will consider the
    // project dirty.
    isDirty = true;
  }

  /// Pushes the given command to the undo/redo queue without executing it
  /// (unless [execute] is set to true).
  void push(Command command, {bool execute = false}) {
    if (execute) {
      command.execute(this as ProjectModel);
    }

    if (_undoGroupActive) {
      _undoGroupAccumulator.add(command);
    } else {
      _commandStack.push(command);
    }

    // If we receive an action that can be undone, then we will consider the
    // project dirty.
    isDirty = true;
  }

  void _assertUndoGroupInactive() {
    if (_undoGroupActive) {
      throw AssertionError("Journal page was active but shouldn't have been.");
    }
  }

  /// Undoes the last command in the undo/redo queue.
  void undo() {
    if (!_commandStack.canUndo) return;
    _assertUndoGroupInactive();
    _commandStack.undo();
    isDirty = true;
  }

  /// Redoes the next command in the undo/redo queue.
  void redo() {
    if (!_commandStack.canRedo) return;
    _assertUndoGroupInactive();
    _commandStack.redo();
    isDirty = true;
  }

  /// Starts an undo group.
  ///
  /// Once this is called, any commands that are submitted via [execute] or
  /// [push] will be grouped into a single undo/redo action.
  ///
  /// After the desired actions have been added to the group, [commitUndoGroup]
  /// can be called to finalize the composite undo/redo action.
  void startUndoGroup() {
    _undoGroupActive = true;
  }

  /// Commits an undo group.
  ///
  /// See [startUndoGroup] for details.
  void commitUndoGroup() {
    if (!_undoGroupActive) return;
    if (_undoGroupAccumulator.isEmpty) {
      _undoGroupActive = false;
      return;
    }

    final accumulator = _undoGroupAccumulator;
    _undoGroupAccumulator = [];
    _undoGroupActive = false;

    if (accumulator.length == 1) {
      _commandStack.push(accumulator.first);
      return;
    }

    final command = JournalPageCommand(accumulator);
    _commandStack.push(command);
  }

  void dispose() {
    visualizationProvider.dispose();
    engine.dispose();
  }
}
