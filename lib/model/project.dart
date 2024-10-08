/*
  Copyright (C) 2021 - 2024 Joshua Wade

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

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_queue.dart';
import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/song.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'generator.dart';
import 'shared/hydratable.dart';

part 'project.g.dart';

enum ProjectLayoutKind { arrange, edit, mix }

@AnthemModel.all()
class ProjectModel extends _ProjectModel
    with _$ProjectModel, _$ProjectModelAnthemModelMixin {
  ProjectModel() : super();
  ProjectModel.create() : super.create();

  factory ProjectModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectModelAnthemModelMixin.fromJson(json)..isSaved = true;
}

abstract class _ProjectModel extends Hydratable with Store, AnthemModelBase {
  late SongModel song;

  /// ID of the master output node in the processing graph. Audio that is routed
  /// to this node is sent to the audio output device.
  @anthemObservable
  @hideFromSerialization
  int? masterOutputNodeId;

  /// Map of generators in the project.
  @anthemObservable
  ObservableMap<ID, GeneratorModel> generators = ObservableMap();

  /// List of generator IDs in the project (to preserve order).
  @anthemObservable
  ObservableList<ID> generatorList = ObservableList();

  /// ID of the active instrument, used to determine which instrument is shown
  /// in the channel rack, which is used for piano roll, etc.
  @anthemObservable
  @hideFromSerialization
  ID? activeInstrumentID;

  /// ID of the active automation generator, used to determine which automation
  /// generator is being written to using the automation editor.
  @anthemObservable
  @hideFromSerialization
  ID? activeAutomationGeneratorID;

  /// The ID of the project.
  @hideFromSerialization
  ID id = getID();

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
  late final CommandQueue _commandQueue;

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

  // This method is used for deserialization and so doesn't create new child
  // models.
  _ProjectModel() : super() {
    _commandQueue = CommandQueue(this as ProjectModel);

    _init();
  }

  _ProjectModel.create() : super() {
    _commandQueue = CommandQueue(this as ProjectModel);

    song = SongModel.create(
      project: this as ProjectModel,
    );

    engine = Engine(engineID, this as ProjectModel)..start();

    engine.engineStateStream.listen((state) {
      (this as ProjectModel).engineState = state;
    });

    // We don't need to hydrate here. All `SomeModel.Create()` functions should
    // call hydrate().
    isHydrated = true;

    _init();
  }

  void _init() {
    (this as _$ProjectModelAnthemModelMixin).init();

    addFieldChangedListener((accessors) {
      final accessString = accessors.map((accessor) {
        final type = accessor.fieldType;

        if (type == FieldType.raw) {
          return accessor.fieldName;
        } else if (type == FieldType.list) {
          return '${accessor.fieldName}[${accessor.index}]';
        } else if (type == FieldType.map) {
          return "${accessor.fieldName}['${accessor.key}']";
        }
      }).join('.');

      print('ProjectModel changed: project.$accessString');
    });
  }

  // Initializes this project in the engine
  Future<void> createInEngine() async {
    masterOutputNodeId =
        await engine.processingGraphApi.getMasterOutputNodeId();

    await song.createInEngine(engine);

    for (final generator in generators.values) {
      await generator.createInEngine(engine);
    }
  }

  /// This function is run after deserialization. It allows us to do some setup
  /// that the deserialization step can't do for us.
  void hydrate() {
    song.hydrate(
      project: this as ProjectModel,
    );

    engine = Engine(engineID, this as ProjectModel)..start();

    isHydrated = true;
  }

  /// Executes the given command on the project and pushes it to the undo/redo
  /// queue.
  void execute(Command command, {bool push = true}) {
    command.execute(this as ProjectModel);

    if (_journalPageActive) {
      _journalPageAccumulator.add(command);
    } else {
      _commandQueue.push(command);
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
      _commandQueue.push(command);
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
    _commandQueue.undo();
  }

  /// Redoes the next command in the undo/redo queue.
  void redo() {
    _assertJournalInactive();
    _commandQueue.redo();
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
      _commandQueue.push(accumulator.first);
      return;
    }

    final command = JournalPageCommand(accumulator);
    _commandQueue.push(command);
  }
}

/// Used to describe which detail view is active in the project sidebar, if any
abstract class DetailViewKind {}

class PatternDetailViewKind extends DetailViewKind {
  ID patternID;
  PatternDetailViewKind(this.patternID);
}

class ArrangementDetailViewKind extends DetailViewKind {
  ID arrangementID;
  ArrangementDetailViewKind(this.arrangementID);
}

class TimeSignatureChangeDetailViewKind extends DetailViewKind {
  ID? arrangementID;
  ID? patternID;
  ID changeID;
  TimeSignatureChangeDetailViewKind({
    this.arrangementID,
    this.patternID,
    required this.changeID,
  });
}
