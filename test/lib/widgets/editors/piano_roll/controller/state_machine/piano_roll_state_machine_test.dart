/*
  Copyright (C) 2026 Joshua Wade

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
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:mockito/mockito.dart';

class _StoppedEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();

  @override
  bool get isRunning => false;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;
}

class _RecordedLiveEvent {
  final Id liveEventProviderNodeId;
  final Object event;

  const _RecordedLiveEvent({
    required this.liveEventProviderNodeId,
    required this.event,
  });
}

class _RecordingProcessingGraphApi implements ProcessingGraphApi {
  final List<_RecordedLiveEvent> liveEvents = [];

  @override
  Future<void> compile() async {}

  @override
  Future<String> getPluginState(Id nodeId) async => '';

  @override
  void sendLiveEvent(Id liveEventProviderNodeId, Object event) {
    liveEvents.add(
      _RecordedLiveEvent(
        liveEventProviderNodeId: liveEventProviderNodeId,
        event: event,
      ),
    );
  }

  @override
  void setPluginState(Id nodeId, String state) {}
}

class _NoopSequencerApi implements SequencerApi {
  @override
  void cleanUpTrack(String trackId) {}

  @override
  void compileArrangement(
    Id arrangementId, {
    List<String>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void compilePattern(
    Id patternId, {
    List<String>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void jumpPlayheadTo(double offset) {}

  @override
  void updateLoopPoints(String sequenceId) {}
}

class _RunningEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();
  final _RecordingProcessingGraphApi _processingGraphApi;
  final _NoopSequencerApi _sequencerApi = _NoopSequencerApi();
  bool _isRunning = false;

  _RunningEngine(this._processingGraphApi);

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;

  @override
  ProcessingGraphApi get processingGraphApi => _processingGraphApi;

  @override
  SequencerApi get sequencerApi => _sequencerApi;

  void setRunning(bool isRunning) {
    _isRunning = isRunning;
  }
}

class _TrackIds {
  static const instrument = 'instrument';
  static const master = 'master';
}

TrackModel _makeTrack(Id id, String name, TrackType type) {
  return TrackModel(name: name, color: AnthemColor.randomHue(), type: type)
    ..id = id;
}

class _PianoRollStateMachineTestFixture {
  static const pianoRollSize = Size(960, 240);
  static const liveEventProviderNodeId = 'live-event-provider';

  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final ProjectViewModel projectViewModel;
  final ProjectController projectController;
  final PianoRollController controller;
  final PatternModel pattern;
  final Id trackId;
  final _RecordingProcessingGraphApi? recordingProcessingGraphApi;
  final _RunningEngine? runningEngine;

  _PianoRollStateMachineTestFixture._({
    required this.project,
    required this.viewModel,
    required this.projectViewModel,
    required this.projectController,
    required this.controller,
    required this.pattern,
    required this.trackId,
    required this.recordingProcessingGraphApi,
    required this.runningEngine,
  });

  factory _PianoRollStateMachineTestFixture.create({
    bool enableLiveEvents = false,
  }) {
    final project = ProjectModel();
    project.isHydrated = true;
    final recordingProcessingGraphApi = enableLiveEvents
        ? _RecordingProcessingGraphApi()
        : null;
    final runningEngine = enableLiveEvents
        ? _RunningEngine(recordingProcessingGraphApi!)
        : null;
    project.engine = enableLiveEvents ? runningEngine! : _StoppedEngine();
    project.sequence = SequencerModel.create();

    project.tracks = AnthemObservableMap.of({
      _TrackIds.instrument: _makeTrack(
        _TrackIds.instrument,
        'Instrument',
        TrackType.instrument,
      ),
      _TrackIds.master: _makeTrack(_TrackIds.master, 'Master', TrackType.audio),
    });
    project.trackOrder = AnthemObservableList.of([_TrackIds.instrument]);
    project.sendTrackOrder = AnthemObservableList.of([_TrackIds.master]);
    if (enableLiveEvents) {
      project.tracks[_TrackIds.instrument]!.liveEventProviderNodeId =
          liveEventProviderNodeId;
    }

    final pattern = PatternModel.create(name: 'Pattern 1');
    project.sequence.patterns = AnthemObservableMap.of({pattern.id: pattern});
    project.sequence.setActivePattern(pattern.id);
    project.sequence.setActiveTrack(_TrackIds.instrument);

    final viewModel = PianoRollViewModel(
      keyHeight: 14.0,
      // Hack: cuts off the top horizontal line. Otherwise the default view looks off
      keyValueAtTop: 63.95,
      timeView: TimeRange(0, 3072),
    );
    final projectViewModel = ProjectViewModel()
      ..activePanel = PanelKind.pianoRoll;
    final projectController = ProjectController(project, projectViewModel);

    AnthemStore.instance.projects[project.id] = project;
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides(
        projectViewModel: (_, _) => projectViewModel,
        projectController: (_, _) => projectController,
      ),
    );

    final controller = PianoRollController(
      project: project,
      viewModel: viewModel,
    );

    return _PianoRollStateMachineTestFixture._(
      project: project,
      viewModel: viewModel,
      projectViewModel: projectViewModel,
      projectController: projectController,
      controller: controller,
      pattern: pattern,
      trackId: _TrackIds.instrument,
      recordingProcessingGraphApi: recordingProcessingGraphApi,
      runningEngine: runningEngine,
    );
  }

  List<NoteModel> get notes => pattern.notes.toList(growable: false);
  List<_RecordedLiveEvent> get liveEvents =>
      recordingProcessingGraphApi?.liveEvents.toList(growable: false) ??
      const <_RecordedLiveEvent>[];
  PianoRollStateMachine get stateMachine => controller.stateMachine;
  PianoRollInteractionFamily? get activeInteractionFamily =>
      controller.activeInteractionFamily;
  PianoRollInteractionBackend? get activeInteractionBackend =>
      controller.activeInteractionBackend;

  PianoRollIdleState get idleState =>
      stateMachine.states[PianoRollIdleState]! as PianoRollIdleState;
  PianoRollPointerSessionState get pointerSessionState =>
      stateMachine.states[PianoRollPointerSessionState]!
          as PianoRollPointerSessionState;
  PianoRollNoteInteractionState get noteInteractionState =>
      stateMachine.states[PianoRollNoteInteractionState]!
          as PianoRollNoteInteractionState;
  PianoRollSelectionBoxState get selectionBoxState =>
      stateMachine.states[PianoRollSelectionBoxState]!
          as PianoRollSelectionBoxState;
  PianoRollEraseNotesState get eraseNotesState =>
      stateMachine.states[PianoRollEraseNotesState]!
          as PianoRollEraseNotesState;
  PianoRollMoveNotesState get moveNotesState =>
      stateMachine.states[PianoRollMoveNotesState]! as PianoRollMoveNotesState;
  PianoRollResizeNotesState get resizeNotesState =>
      stateMachine.states[PianoRollResizeNotesState]!
          as PianoRollResizeNotesState;
  PianoRollCreateNoteState get createNoteState =>
      stateMachine.states[PianoRollCreateNoteState]!
          as PianoRollCreateNoteState;

  void routeFamilyToStateMachineForTesting(PianoRollInteractionFamily family) {
    controller.setInteractionBackendForTesting(
      family,
      PianoRollInteractionBackend.stateMachine,
    );
  }

  KeyboardModifiers _keyboardModifiers({
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    final modifiers = KeyboardModifiers();
    if (ctrl) {
      modifiers.setCtrl(true);
    }
    if (alt) {
      modifiers.setAlt(true);
    }
    if (shift) {
      modifiers.setShift(true);
    }
    return modifiers;
  }

  NoteModel addNote({
    required int key,
    required int offset,
    required int length,
    double velocity = 0.75,
    double pan = 0,
  }) {
    final note = NoteModel(
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );
    project.execute(
      AddNoteCommand(patternID: pattern.id, note: note),
      push: false,
    );
    return note;
  }

  NoteModel noteById(Id id) {
    return pattern.notes.firstWhere((note) => note.id == id);
  }

  void selectNotes(Iterable<Id> noteIds) {
    viewModel.selectedNotes = ObservableSet.of(noteIds.toSet());
  }

  void setTool(EditorTool tool) {
    viewModel.tool = tool;
  }

  void deleteSelected() {
    controller.deleteSelected();
  }

  void enableLiveEvents() {
    runningEngine?.setRunning(true);
  }

  List<DivisionChange> divisionChanges() {
    return getDivisionChanges(
      viewWidthInPixels: pianoRollSize.width,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: pattern.timeSignatureChanges,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );
  }

  int snappedTime(int rawTime, {bool round = false, int startTime = 0}) {
    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: divisionChanges(),
      round: round,
      startTime: startTime,
    );
  }

  int snapSizeAt(int offset) {
    final changes = divisionChanges();
    var activeChange = changes.first;

    for (final change in changes) {
      if (change.offset > offset) {
        break;
      }
      activeChange = change;
    }

    return activeChange.divisionSnapSize;
  }

  void pointerDown({
    required double key,
    required double offset,
    Id? noteUnderCursor,
    bool isResize = false,
    int buttons = kPrimaryMouseButton,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    int pointer = 1,
  }) {
    controller.pointerDown(
      PianoRollPointerDownEvent(
        key: key,
        offset: offset,
        pointerEvent: PointerDownEvent(
          pointer: pointer,
          position: Offset(offset, key),
          buttons: buttons,
        ),
        pianoRollSize: pianoRollSize,
        keyboardModifiers: _keyboardModifiers(
          ctrl: ctrl,
          alt: alt,
          shift: shift,
        ),
        noteUnderCursor: noteUnderCursor,
        isResize: isResize,
      ),
    );
  }

  void pointerMove({
    required double key,
    required double offset,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    int pointer = 1,
  }) {
    controller.pointerMove(
      PianoRollPointerMoveEvent(
        key: key,
        offset: offset,
        pointerEvent: PointerMoveEvent(
          pointer: pointer,
          position: Offset(offset, key),
        ),
        pianoRollSize: pianoRollSize,
        keyboardModifiers: _keyboardModifiers(
          ctrl: ctrl,
          alt: alt,
          shift: shift,
        ),
      ),
    );
  }

  void pointerUp({
    required double key,
    required double offset,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    int pointer = 1,
  }) {
    controller.pointerUp(
      PianoRollPointerUpEvent(
        key: key,
        offset: offset,
        pointerEvent: PointerUpEvent(
          pointer: pointer,
          position: Offset(offset, key),
        ),
        pianoRollSize: pianoRollSize,
        keyboardModifiers: _keyboardModifiers(
          ctrl: ctrl,
          alt: alt,
          shift: shift,
        ),
      ),
    );
  }

  void pointerCancel({
    required double key,
    required double offset,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    int pointer = 1,
  }) {
    controller.pointerUp(
      PianoRollPointerUpEvent(
        key: key,
        offset: offset,
        pointerEvent: PointerCancelEvent(
          pointer: pointer,
          position: Offset(offset, key),
        ),
        pianoRollSize: pianoRollSize,
        keyboardModifiers: _keyboardModifiers(
          ctrl: ctrl,
          alt: alt,
          shift: shift,
        ),
      ),
    );
  }

  void expectSelection(Iterable<Id> expected) {
    expect(
      viewModel.selectedNotes.nonObservableInner,
      equals(expected.toSet()),
    );
  }

  void expectSelectionBox({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final selectionBox = viewModel.selectionBox;
    expect(selectionBox, isNotNull);
    expect(selectionBox!.left, equals(left));
    expect(selectionBox.top, equals(top));
    expect(selectionBox.width, equals(width));
    expect(selectionBox.height, equals(height));
  }

  void expectNoActiveTransientState() {
    expect(viewModel.selectionBox, isNull);
    expect(viewModel.pressedNote, isNull);
  }

  void dispose() {
    controller.dispose();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _PianoRollStateMachineTestFixture fixture;

  setUp(() {
    fixture = _PianoRollStateMachineTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('fixture', () {
    test('creates an active pattern, track, and controller', () {
      expect(
        fixture.project.sequence.activePatternID,
        equals(fixture.pattern.id),
      );
      expect(
        fixture.project.sequence.activeTrackID,
        equals(_TrackIds.instrument),
      );
      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.tool, equals(EditorTool.pencil));
    });

    test('controller owns an inert state machine shell', () {
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.stateMachine.controller, same(fixture.controller));
      expect(fixture.pointerSessionState.parentState, same(fixture.idleState));
      expect(
        fixture.noteInteractionState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.selectionBoxState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.eraseNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.moveNotesState.parentState,
        same(fixture.noteInteractionState),
      );
      expect(
        fixture.resizeNotesState.parentState,
        same(fixture.noteInteractionState),
      );
      expect(
        fixture.createNoteState.parentState,
        same(fixture.noteInteractionState),
      );
    });

    test('controller dispose is idempotent', () {
      fixture.controller.dispose();
      fixture.controller.dispose();
    });

    test(
      'controller defaults selection and erase to machine and all note interactions to legacy',
      () {
        expect(
          fixture.controller.backendForFamily(
            PianoRollInteractionFamily.selectionBox,
          ),
          equals(PianoRollInteractionBackend.stateMachine),
        );
        expect(
          fixture.controller.backendForFamily(PianoRollInteractionFamily.erase),
          equals(PianoRollInteractionBackend.stateMachine),
        );
        expect(
          fixture.controller.backendForFamily(
            PianoRollInteractionFamily.moveNotes,
          ),
          equals(PianoRollInteractionBackend.legacy),
        );
        expect(
          fixture.controller.backendForFamily(
            PianoRollInteractionFamily.resizeNotes,
          ),
          equals(PianoRollInteractionBackend.legacy),
        );
        expect(
          fixture.controller.backendForFamily(
            PianoRollInteractionFamily.createNote,
          ),
          equals(PianoRollInteractionBackend.legacy),
        );
      },
    );
  });

  group('routing', () {
    test('selection-box routing latches a machine route until pointer up', () {
      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.selectionBox),
      );
      expect(
        fixture.activeInteractionBackend,
        equals(PianoRollInteractionBackend.stateMachine),
      );
      expect(
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.selectionBox),
      );
      expect(
        fixture.activeInteractionBackend,
        equals(PianoRollInteractionBackend.stateMachine),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
      expect(
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.activeInteractionBackend, isNull);
    });

    test('pointer cancel clears the latched route', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(
        fixture.activeInteractionBackend,
        equals(PianoRollInteractionBackend.legacy),
      );

      fixture.pointerCancel(key: 61.5, offset: 173.8, alt: true);

      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.activeInteractionBackend, isNull);
    });

    test('erase routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: note.id,
        buttons: kSecondaryMouseButton,
      );

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.erase),
      );
      expect(
        fixture.activeInteractionBackend,
        equals(PianoRollInteractionBackend.stateMachine),
      );
      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerMove(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerUp(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.activeInteractionBackend, isNull);
    });

    test('a configured legacy family can route to the machine intake stub', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);
      fixture.routeFamilyToStateMachineForTesting(
        PianoRollInteractionFamily.moveNotes,
      );

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(
        fixture.activeInteractionBackend,
        equals(PianoRollInteractionBackend.stateMachine),
      );
      expect(fixture.stateMachine.adaptedPointerDownCount, equals(1));
      expect(fixture.stateMachine.adaptedPointerMoveCount, equals(0));
      expect(fixture.stateMachine.adaptedPointerUpCount, equals(0));
      expect(
        fixture.stateMachine.currentState,
        same(fixture.pointerSessionState),
      );

      fixture.pointerMove(key: 61.5, offset: 120);

      expect(fixture.stateMachine.adaptedPointerMoveCount, equals(1));
      expect(fixture.viewModel.selectionBox, isNull);

      fixture.pointerUp(key: 61.5, offset: 120);

      expect(fixture.stateMachine.adaptedPointerUpCount, equals(1));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.activeInteractionBackend, isNull);
    });
  });

  group('selection box interactions', () {
    test('ctrl drag clears a previous selection when shift is not held', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      final noteC = fixture.addNote(key: 72, offset: 600, length: 48);
      fixture.selectNotes([noteC.id]);

      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);
      fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test(
      'ctrl drag creates an additive selection box and keeps result on up',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
        fixture.addNote(key: 72, offset: 600, length: 48);

        fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
        fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

        fixture.expectSelectionBox(left: 80, top: 59.5, width: 280, height: 6);
        fixture.expectSelection([noteA.id, noteB.id]);

        fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

        expect(fixture.viewModel.selectionBox, isNull);
        fixture.expectSelection([noteA.id, noteB.id]);
        fixture.expectNoActiveTransientState();
      },
    );

    test('shift drag in select tool creates a subtractive selection box', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      final noteC = fixture.addNote(key: 70, offset: 480, length: 48);
      fixture.selectNotes([noteA.id, noteB.id, noteC.id]);
      fixture.setTool(EditorTool.select);

      fixture.pointerDown(
        key: 64.5,
        offset: 300,
        shift: true,
        noteUnderCursor: noteB.id,
      );
      fixture.pointerMove(key: 59.5, offset: 80, shift: true);

      fixture.expectSelection([noteC.id]);

      fixture.pointerUp(key: 59.5, offset: 80, shift: true);

      expect(fixture.viewModel.selectionBox, isNull);
      fixture.expectSelection([noteC.id]);
    });

    test('select tool drag creates an additive selection box without ctrl', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      fixture.setTool(EditorTool.select);

      fixture.pointerDown(key: 59.5, offset: 80);
      fixture.pointerMove(key: 65.5, offset: 360);
      fixture.pointerUp(key: 65.5, offset: 360);

      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test(
      'pointer cancel clears selection box but preserves last selection result',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 288, length: 48);

        fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
        fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);
        fixture.pointerCancel(key: 65.5, offset: 360, ctrl: true);

        expect(fixture.viewModel.selectionBox, isNull);
        fixture.expectSelection([noteA.id, noteB.id]);
        fixture.expectNoActiveTransientState();
      },
    );
  });

  group('erase interactions', () {
    test(
      'secondary click deletes a note, clears selection, and supports undo',
      () {
        final note = fixture.addNote(key: 60, offset: 96, length: 48);
        fixture.addNote(key: 64, offset: 288, length: 48);
        fixture.selectNotes([note.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 96,
          noteUnderCursor: note.id,
          buttons: kSecondaryMouseButton,
        );

        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );
        fixture.expectSelection(const []);

        fixture.pointerUp(key: 60.5, offset: 96);

        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );

        fixture.project.undo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          contains(note.id),
        );

        fixture.project.redo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );
        fixture.expectNoActiveTransientState();
      },
    );

    test('eraser tool deletes with the primary button', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);
      fixture.setTool(EditorTool.eraser);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: note.id,
        buttons: kPrimaryMouseButton,
      );
      fixture.pointerUp(key: 60.5, offset: 96);

      expect(fixture.notes, isEmpty);
    });

    test('drag erase deletes multiple notes and undoes as one action', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 60, offset: 192, length: 48);
      final noteC = fixture.addNote(key: 60, offset: 288, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: noteA.id,
        buttons: kSecondaryMouseButton,
      );
      fixture.pointerMove(key: 60.5, offset: 336);
      fixture.pointerUp(key: 60.5, offset: 336);

      expect(fixture.notes, isEmpty);

      fixture.project.undo();
      expect(
        fixture.notes.map((note) => note.id).toSet(),
        equals({noteA.id, noteB.id, noteC.id}),
      );

      fixture.project.redo();
      expect(fixture.notes, isEmpty);
    });

    test(
      'secondary click on a resize handle outside the note body does not delete',
      () {
        final note = fixture.addNote(key: 60, offset: 96, length: 48);

        fixture.pointerDown(
          key: 60.5,
          offset: 144,
          noteUnderCursor: note.id,
          buttons: kSecondaryMouseButton,
        );
        fixture.pointerUp(key: 60.5, offset: 144);

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([note.id]),
        );
      },
    );

    test(
      'overlapping notes are ignored until the cursor leaves and re-enters',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 120);
        final noteB = fixture.addNote(key: 60, offset: 120, length: 120);

        fixture.pointerDown(
          key: 60.5,
          offset: 130,
          noteUnderCursor: noteA.id,
          buttons: kSecondaryMouseButton,
        );

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 131);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 260);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 300);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 150);
        expect(fixture.notes, isEmpty);

        fixture.pointerUp(key: 60.5, offset: 150);
      },
    );
  });

  group('controller commands', () {
    test(
      'deleteSelected removes selected notes, clears selection, and undoes',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
        final noteC = fixture.addNote(key: 67, offset: 288, length: 48);
        fixture.selectNotes([noteA.id, noteC.id]);

        fixture.deleteSelected();

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );
        fixture.expectSelection(const []);

        fixture.project.undo();
        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id, noteC.id}),
        );

        fixture.project.redo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );
        fixture.expectSelection(const []);
      },
    );
  });

  group('live note preview interactions', () {
    test(
      'move preview sends note on/off events as the pitch changes',
      () async {
        final liveFixture = _PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        final note = liveFixture.addNote(key: 60, offset: 100, length: 48);

        liveFixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
        );
        liveFixture.pointerMove(key: 61.5, offset: 155.9, alt: true);
        liveFixture.pointerUp(key: 61.5, offset: 155.9, alt: true);

        expect(liveFixture.liveEvents, hasLength(4));

        final first = liveFixture.liveEvents[0];
        expect(
          first.liveEventProviderNodeId,
          equals(_PianoRollStateMachineTestFixture.liveEventProviderNodeId),
        );
        expect(first.event, isA<LiveEventRequestNoteOnEvent>());
        expect((first.event as LiveEventRequestNoteOnEvent).pitch, equals(60));

        final second = liveFixture.liveEvents[1];
        expect(second.event, isA<LiveEventRequestNoteOffEvent>());
        expect(
          (second.event as LiveEventRequestNoteOffEvent).pitch,
          equals(60),
        );

        final third = liveFixture.liveEvents[2];
        expect(third.event, isA<LiveEventRequestNoteOnEvent>());
        expect((third.event as LiveEventRequestNoteOnEvent).pitch, equals(61));

        final fourth = liveFixture.liveEvents[3];
        expect(fourth.event, isA<LiveEventRequestNoteOffEvent>());
        expect(
          (fourth.event as LiveEventRequestNoteOffEvent).pitch,
          equals(61),
        );
      },
    );

    test(
      'create-note preview sends note off for the final preview pitch on cancel',
      () async {
        final liveFixture = _PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        liveFixture.viewModel.cursorNoteLength = 48;

        liveFixture.pointerDown(key: 60.9, offset: 145.2, alt: true);
        liveFixture.pointerMove(key: 63.5, offset: 173.8, alt: true);
        liveFixture.pointerCancel(key: 63.5, offset: 173.8, alt: true);

        expect(liveFixture.liveEvents, hasLength(4));

        final events = liveFixture.liveEvents
            .map((entry) => entry.event)
            .toList(growable: false);
        expect(events[0], isA<LiveEventRequestNoteOnEvent>());
        expect((events[0] as LiveEventRequestNoteOnEvent).pitch, equals(60));
        expect(events[1], isA<LiveEventRequestNoteOffEvent>());
        expect((events[1] as LiveEventRequestNoteOffEvent).pitch, equals(60));
        expect(events[2], isA<LiveEventRequestNoteOnEvent>());
        expect((events[2] as LiveEventRequestNoteOnEvent).pitch, equals(63));
        expect(events[3], isA<LiveEventRequestNoteOffEvent>());
        expect((events[3] as LiveEventRequestNoteOffEvent).pitch, equals(63));
      },
    );

    test(
      'controller dispose sends note off for any active live preview note',
      () async {
        final liveFixture = _PianoRollStateMachineTestFixture.create(
          enableLiveEvents: true,
        );
        addTearDown(liveFixture.dispose);
        await Future<void>.delayed(Duration.zero);
        liveFixture.enableLiveEvents();

        final note = liveFixture.addNote(key: 60, offset: 100, length: 48);

        liveFixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
        );

        expect(liveFixture.liveEvents, hasLength(1));
        expect(
          liveFixture.liveEvents.single.event,
          isA<LiveEventRequestNoteOnEvent>(),
        );
        expect(
          (liveFixture.liveEvents.single.event as LiveEventRequestNoteOnEvent)
              .pitch,
          equals(60),
        );

        liveFixture.controller.dispose();

        expect(liveFixture.liveEvents, hasLength(2));
        expect(
          liveFixture.liveEvents[1].event,
          isA<LiveEventRequestNoteOffEvent>(),
        );
        expect(
          (liveFixture.liveEvents[1].event as LiveEventRequestNoteOffEvent)
              .pitch,
          equals(60),
        );
      },
    );
  });

  group('move interactions', () {
    test('moves a single note with snapping and supports undo and redo', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);
      fixture.selectNotes(['other-selected-note']);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 155);

      final movedNote = fixture.noteById(note.id);
      expect(
        movedNote.offset,
        equals(fixture.snappedTime(155, round: true, startTime: 100)),
      );
      expect(movedNote.key, equals(62));

      fixture.pointerUp(key: 62.5, offset: 155);

      fixture.expectSelection(const []);
      fixture.expectNoActiveTransientState();

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));

      fixture.project.redo();
      expect(
        fixture.noteById(note.id).offset,
        equals(fixture.snappedTime(155, round: true, startTime: 100)),
      );
      expect(fixture.noteById(note.id).key, equals(62));
    });

    test('pointer cancel still commits a move session and can be undone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 173.8, alt: true);
      fixture.pointerCancel(key: 61.5, offset: 173.8, alt: true);

      expect(fixture.noteById(note.id).offset, equals(173));
      expect(fixture.noteById(note.id).key, equals(61));

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
    });

    test('moves a single note without snapping when alt is held', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 155.9, alt: true);
      fixture.pointerUp(key: 61.5, offset: 155.9, alt: true);

      expect(fixture.noteById(note.id).offset, equals(155));
      expect(fixture.noteById(note.id).key, equals(61));
    });

    test('holding shift during drag locks pitch changes', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 200, shift: true);
      fixture.pointerUp(key: 62.5, offset: 200, shift: true);

      expect(fixture.noteById(note.id).key, equals(60));
      expect(
        fixture.noteById(note.id).offset,
        equals(fixture.snappedTime(200, round: true, startTime: 100)),
      );
    });

    test('holding ctrl during drag locks time changes', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 200, ctrl: true);
      fixture.pointerUp(key: 62.5, offset: 200, ctrl: true);

      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(62));
    });

    test('single-note shift drag duplicates and moves the original note', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 100,
        noteUnderCursor: note.id,
        shift: true,
      );

      expect(fixture.notes.length, equals(2));

      fixture.pointerMove(key: 62.5, offset: 200);
      fixture.pointerUp(key: 62.5, offset: 200);

      final original = fixture.noteById(note.id);
      final duplicate = fixture.notes.firstWhere(
        (candidate) => candidate.id != note.id,
      );
      expect(
        original.offset,
        equals(fixture.snappedTime(200, round: true, startTime: 100)),
      );
      expect(original.key, equals(62));
      expect(duplicate.offset, equals(100));
      expect(duplicate.key, equals(60));

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
      expect(fixture.notes.length, equals(2));

      fixture.project.undo();
      expect(
        fixture.notes.map((note) => note.id).toList(),
        orderedEquals([note.id]),
      );
    });

    test('moves a selected group without duplicating it', () {
      final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: noteA.id);
      fixture.pointerMove(key: 62.5, offset: 190);
      fixture.pointerUp(key: 62.5, offset: 190);

      final movedDistance =
          fixture.snappedTime(190, round: true, startTime: 100) - 100;
      expect(fixture.noteById(noteA.id).offset, equals(100 + movedDistance));
      expect(fixture.noteById(noteB.id).offset, equals(180 + movedDistance));
      expect(fixture.noteById(noteA.id).key, equals(62));
      expect(fixture.noteById(noteB.id).key, equals(66));
      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test('selection move clamps the entire group at the pattern start', () {
      final noteA = fixture.addNote(key: 60, offset: 20, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 100, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.pointerDown(key: 60.5, offset: 20, noteUnderCursor: noteA.id);
      fixture.pointerMove(key: 58.5, offset: -40, alt: true);
      fixture.pointerUp(key: 58.5, offset: -40, alt: true);

      expect(fixture.noteById(noteA.id).offset, equals(0));
      expect(fixture.noteById(noteB.id).offset, equals(80));
      expect(fixture.noteById(noteA.id).key, equals(58));
      expect(fixture.noteById(noteB.id).key, equals(62));
    });

    test(
      'shift drag on a selected group duplicates the selection and moves the clones',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: noteA.id,
          shift: true,
        );

        expect(fixture.notes.length, equals(4));
        final clonedIds = fixture.viewModel.selectedNotes.nonObservableInner
            .toSet();
        expect(clonedIds, hasLength(2));
        expect(clonedIds.contains(noteA.id), isFalse);
        expect(clonedIds.contains(noteB.id), isFalse);

        fixture.pointerMove(key: 61.5, offset: 200);
        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));

        final movedDistance =
            fixture.snappedTime(200, round: true, startTime: 100) - 100;
        final clonePositions = clonedIds.map((clonedId) {
          final clone = fixture.noteById(clonedId);
          return (key: clone.key, offset: clone.offset);
        }).toSet();
        expect(
          clonePositions,
          equals({
            (key: 61, offset: 100 + movedDistance),
            (key: 65, offset: 180 + movedDistance),
          }),
        );
      },
    );

    test(
      'undoing a duplicated selection move removes the clones in one action',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: noteA.id,
          shift: true,
        );
        fixture.pointerMove(key: 61.5, offset: 200);
        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.notes, hasLength(4));

        fixture.project.undo();

        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id}),
        );
        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));
      },
    );

    test('move clamps at the pattern start and valid note range', () {
      final note = fixture.addNote(key: 127, offset: 10, length: 48);

      fixture.pointerDown(key: 127.5, offset: 10, noteUnderCursor: note.id);
      fixture.pointerMove(key: 200.5, offset: -50, alt: true);
      fixture.pointerUp(key: 200.5, offset: -50, alt: true);

      expect(fixture.noteById(note.id).offset, equals(0));
      expect(fixture.noteById(note.id).key, equals(maxKeyValue.round()));
    });
  });

  group('resize interactions', () {
    test(
      'resize on an unselected note clears the selection and only resizes that note',
      () {
        final selectedNote = fixture.addNote(key: 60, offset: 100, length: 96);
        final resizedNote = fixture.addNote(key: 64, offset: 220, length: 96);
        fixture.selectNotes([selectedNote.id]);

        fixture.pointerDown(
          key: 64.5,
          offset: 316,
          noteUnderCursor: resizedNote.id,
          isResize: true,
        );
        fixture.pointerMove(key: 64.5, offset: 360, alt: true);
        fixture.pointerUp(key: 64.5, offset: 360, alt: true);

        fixture.expectSelection(const []);
        expect(fixture.noteById(selectedNote.id).length, equals(96));
        expect(fixture.noteById(resizedNote.id).length, equals(140));
      },
    );

    test(
      'resizes a single note with snapping and updates cursor note parameters',
      () {
        final note = fixture.addNote(
          key: 60,
          offset: 100,
          length: 96,
          velocity: 0.4,
          pan: -0.2,
        );
        fixture.viewModel.cursorNoteLength = 12;
        fixture.viewModel.cursorNoteVelocity = 0.1;
        fixture.viewModel.cursorNotePan = 0.8;

        fixture.pointerDown(
          key: 60.5,
          offset: 196,
          noteUnderCursor: note.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: 250);

        final snappedOriginal = fixture.snappedTime(196, round: true);
        final snappedEvent = fixture.snappedTime(250, round: true);
        final expectedLength = 96 + (snappedEvent - snappedOriginal);

        expect(fixture.noteById(note.id).length, equals(expectedLength));
        expect(fixture.viewModel.cursorNoteLength, equals(expectedLength));
        expect(fixture.viewModel.cursorNoteVelocity, equals(0.4));
        expect(fixture.viewModel.cursorNotePan, equals(-0.2));

        fixture.pointerUp(key: 60.5, offset: 250);

        fixture.project.undo();
        expect(fixture.noteById(note.id).length, equals(96));

        fixture.project.redo();
        expect(fixture.noteById(note.id).length, equals(expectedLength));
      },
    );

    test('pointer cancel still commits a resize session and can be undone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

      fixture.pointerDown(
        key: 60.5,
        offset: 196,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 240, alt: true);
      fixture.pointerCancel(key: 60.5, offset: 240, alt: true);

      expect(fixture.noteById(note.id).length, equals(140));

      fixture.project.undo();
      expect(fixture.noteById(note.id).length, equals(96));
    });

    test(
      'resizing a selected group applies the same diff to every selected note',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 96);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 144);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 196,
          noteUnderCursor: noteA.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: 221, alt: true);
        fixture.pointerUp(key: 60.5, offset: 221, alt: true);

        expect(fixture.noteById(noteA.id).length, equals(121));
        expect(fixture.noteById(noteB.id).length, equals(169));

        fixture.project.undo();
        expect(fixture.noteById(noteA.id).length, equals(96));
        expect(fixture.noteById(noteB.id).length, equals(144));
      },
    );

    test('alt resize clamps the minimum note length to 1 tick', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 10);

      fixture.pointerDown(
        key: 60.5,
        offset: 110,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 50, alt: true);
      fixture.pointerUp(key: 60.5, offset: 50, alt: true);

      expect(fixture.noteById(note.id).length, equals(1));
    });

    test(
      'snapped resize clamps the minimum note length to the current snap size',
      () {
        final note = fixture.addNote(key: 60, offset: 100, length: 192);

        fixture.pointerDown(
          key: 60.5,
          offset: 292,
          noteUnderCursor: note.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: 96);
        fixture.pointerUp(key: 60.5, offset: 96);

        expect(
          fixture.noteById(note.id).length,
          equals(fixture.snapSizeAt(100)),
        );
      },
    );

    test(
      'resize press without a note under cursor throws an argument error',
      () {
        expect(
          () => fixture.pointerDown(key: 60.5, offset: 196, isResize: true),
          throwsArgumentError,
        );
      },
    );
  });

  group('create-note interactions', () {
    test(
      'empty-space pencil press creates a snapped note using cursor parameters',
      () {
        fixture.viewModel.cursorNoteLength = 48;
        fixture.viewModel.cursorNoteVelocity = 0.25;
        fixture.viewModel.cursorNotePan = 0.6;

        fixture.pointerDown(key: 60.9, offset: 145.2);

        expect(fixture.notes, hasLength(1));
        final note = fixture.notes.single;
        expect(note.key, equals(60));
        expect(note.offset, equals(fixture.snappedTime(145)));
        expect(note.length, equals(48));
        expect(note.velocity, equals(0.25));
        expect(note.pan, equals(0.6));
        expect(fixture.viewModel.pressedNote, equals(note.id));

        fixture.pointerUp(key: 60.9, offset: 145.2);

        fixture.expectNoActiveTransientState();

        fixture.project.undo();
        expect(fixture.notes, isEmpty);
      },
    );

    test('negative-time empty-space press does not create a note', () {
      fixture.pointerDown(key: 60.9, offset: -1);

      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.pressedNote, isNull);
    });

    test(
      'created notes can be repositioned during the same gesture and commit on cancel',
      () {
        fixture.viewModel.cursorNoteLength = 48;

        fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

        final createdNoteId = fixture.notes.single.id;

        fixture.pointerMove(key: 63.5, offset: 173.8, alt: true);
        fixture.pointerCancel(key: 63.5, offset: 173.8, alt: true);

        final note = fixture.noteById(createdNoteId);
        expect(note.key, equals(63));
        expect(note.offset, equals(173));

        fixture.project.undo();
        expect(fixture.notes, isEmpty);
      },
    );
  });
}
