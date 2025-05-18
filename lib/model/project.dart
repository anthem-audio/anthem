/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_stack.dart';
import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/sequence.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:anthem/engine_api/messages/messages.dart' as message_api;
import 'package:mobx/mobx.dart';

import 'generator.dart';
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
  ProjectModel() : super() {
    _init();
  }

  ProjectModel.create([super._enginePathOverride]) : super.create() {
    _init();
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final project =
        _$ProjectModelAnthemModelMixin.fromJson(json)
          ..isSaved = true
          // This is the top model in the tree. setParentPropertiesOnChildren will not
          // work correctly if we don't set this.
          ..isTopLevelModel = true;
    project._init();
    return project;
  }

  void _init() {
    // Normally we rely on the fact that this will always be put in the field of
    // another model, which will call setParentPropertiesOnChildren. Since this
    // is the top level, we need to call it ourselves.
    setParentPropertiesOnChildren();
  }
}

abstract class _ProjectModel extends Hydratable with Store, AnthemModelBase {
  /// Represents information about the sequenced content in the project, such as
  /// arrangements and patterns, and their content.
  late SequenceModel sequence;

  /// Represents the processing graph for the project. This is used to route
  /// audio, control and notes between processors, and to eventually route the
  /// resulting audio to the audio output device.
  late ProcessingGraphModel processingGraph;

  /// ID of the master output node in the processing graph. Audio that is routed
  /// to this node is sent to the audio output device.
  @anthemObservable
  @hideFromSerialization
  int? masterOutputNodeId;

  /// Map of generators in the project.
  @anthemObservable
  AnthemObservableMap<Id, GeneratorModel> generators = AnthemObservableMap();

  /// List of generator IDs in the project (to preserve order).
  @anthemObservable
  AnthemObservableList<Id> generatorOrder = AnthemObservableList();

  /// ID of the active instrument, used to determine which instrument is shown
  /// in the channel rack, which is used for piano roll, etc.
  @anthemObservable
  @hideFromSerialization
  Id? activeInstrumentID;

  /// ID of the active automation generator, used to determine which automation
  /// generator is being written to using the automation editor.
  @anthemObservable
  @hideFromSerialization
  Id? activeAutomationGeneratorID;

  /// The ID of the project.
  @hideFromSerialization
  Id id = getId();

  /// The file path of the project.
  @anthemObservable
  @hideFromSerialization
  String? filePath;

  /// Whether or not the project has been saved. If false, the project has
  /// either never been saved, or has been modified since the last save.
  @anthemObservable
  @hideFromSerialization
  bool isSaved = false;

  // Detail view state

  @anthemObservable
  @hide
  DetailViewKind? _selectedDetailView;

  /// `selectedDetailView` controls which detail item (in the left panel) is
  /// active. Detail views contain attributes about various items in the
  /// project, such as patterns, arrangements, notes, etc.
  DetailViewKind? getSelectedDetailView() => _selectedDetailView;

  /// Sets the selected detail view. See getSelectedDetailView() for more info.
  void setSelectedDetailView(DetailViewKind? detailView) {
    _selectedDetailView = detailView;
    if (detailView != null) isDetailViewSelected = true;
  }

  /// Whether the detail view is active. If false, the project explorer is
  /// shown instead.
  @anthemObservable
  @hide
  bool isDetailViewSelected = false;

  // Visual layout flags

  @anthemObservable
  @hide
  bool isProjectExplorerVisible = true;

  @anthemObservable
  @hide
  bool isPatternEditorVisible = true;

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
  List<Command> _journalPageAccumulator = [];

  @hide
  bool _journalPageActive = false;

  // Engine

  @hide
  final engineID = getEngineID();

  @hide
  late Engine engine;

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
    visualizationProvider = VisualizationProvider(this as ProjectModel);
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
    sequence = SequenceModel.create();
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
    engine = Engine(
      engineID,
      this as ProjectModel,
      enginePathOverride: _enginePathOverride,
    )..start();

    engine.engineStateStream.listen((state) {
      (this as ProjectModel).engineState = state;

      // Send model state change messages to the engine
      if (state == EngineState.running) {
        _initializeEngine();
        _attachModelChangeListener();
      }

      if (state == EngineState.stopped) {
        if (_fieldChangedListener != null) {
          // Unhook the model change stream from the engine
          (this as AnthemModelBase).removeFieldChangedListener(
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

  /// Initializes the engine. This is called when the engine is started.
  void _initializeEngine() {
    // Any time the engine starts, we send the entire current model state to the engine
    engine.modelSyncApi.initModel(
      jsonEncode(
        (this as _$ProjectModelAnthemModelMixin).toJson(
          includeFieldsForEngine: true,
        ),
      ),
    );
    // We won't wait for the engine to acknowledge this before saying that
    // we're synced, since any subsequent messages will be processed after
    // the engine has finished processing the init request.
    _modelSyncCompleter.complete();

    // The engine will receive the processing graph when we sync the model,
    // but it still needs to be compiled by the engine for use on the audio
    // thread, so we do that here.
    engine.processingGraphApi.compile();
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

      final convertedAccesses =
          accesses.map((access) {
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
    (this as AnthemModelBase).addFieldChangedListener(_fieldChangedListener!);
  }

  /// Executes the given command on the project and pushes it to the undo/redo
  /// queue.
  void execute(Command command, {bool push = true}) {
    command.execute(this as ProjectModel);

    if (_journalPageActive) {
      _journalPageAccumulator.add(command);
    } else {
      _commandStack.push(command);
    }
  }

  /// Pushes the given command to the undo/redo queue without executing it
  /// (unless [execute] is set to true).
  void push(Command command, {bool execute = false}) {
    if (execute) {
      command.execute(this as ProjectModel);
    }

    if (_journalPageActive) {
      _journalPageAccumulator.add(command);
    } else {
      _commandStack.push(command);
    }
  }

  void _assertJournalInactive() {
    if (_journalPageActive) {
      throw AssertionError("Journal page was active but shouldn't have been.");
    }
  }

  /// Undoes the last command in the undo/redo queue.
  void undo() {
    _assertJournalInactive();
    _commandStack.undo();
  }

  /// Redoes the next command in the undo/redo queue.
  void redo() {
    _assertJournalInactive();
    _commandStack.redo();
  }

  void startJournalPage() {
    _journalPageActive = true;
  }

  void commitJournalPage() {
    if (!_journalPageActive) return;
    if (_journalPageAccumulator.isEmpty) {
      _journalPageActive = false;
      return;
    }

    final accumulator = _journalPageAccumulator;
    _journalPageAccumulator = [];
    _journalPageActive = false;

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

/// Used to describe which detail view is active in the project sidebar, if any
abstract class DetailViewKind {}

class PatternDetailViewKind extends DetailViewKind {
  Id patternID;
  PatternDetailViewKind(this.patternID);
}

class ArrangementDetailViewKind extends DetailViewKind {
  Id arrangementID;
  ArrangementDetailViewKind(this.arrangementID);
}

class TimeSignatureChangeDetailViewKind extends DetailViewKind {
  Id? arrangementID;
  Id? patternID;
  Id changeID;
  TimeSignatureChangeDetailViewKind({
    this.arrangementID,
    this.patternID,
    required this.changeID,
  });
}
