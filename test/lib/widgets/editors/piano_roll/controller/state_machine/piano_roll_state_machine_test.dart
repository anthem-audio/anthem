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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
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
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
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

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
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
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: true, results: []);

  @override
  Future<void> publish() async {}

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
  void cleanUpTrack(Id trackId) {}

  @override
  void compileArrangement(
    Id arrangementId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void compilePattern(
    Id patternId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void jumpPlayheadTo(double offset) {}

  @override
  void updateLoopPoints(Id sequenceId) {}
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
  static const instrument = 1;
  static const master = 2;
}

TrackModel _makeTrack(Id id, String name, TrackType type) {
  return TrackModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    name: name,
    color: AnthemColor.randomHue(),
    type: type,
  );
}

class _PianoRollStateMachineTestFixture {
  static const pianoRollSize = Size(960, 240);
  static const liveEventProviderNodeId = 3;

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
    project.sequence = SequencerModel(idAllocator: _testIdAllocator());

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

    final pattern = PatternModel(
      idAllocator: _testIdAllocator(),
      name: 'Pattern 1',
    );
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
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectViewModelService, (_, _) => projectViewModel),
        overrideService(projectControllerService, (_, _) => projectController),
      ]),
    );

    final controller = PianoRollController(
      project: project,
      viewModel: viewModel,
    );
    controller.onRenderedViewMetricsChanged(
      viewSize: pianoRollSize,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      keyHeight: viewModel.keyHeight,
      keyValueAtTop: viewModel.keyValueAtTop,
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

  List<NoteModel> get notes => pattern.notes.values.toList(growable: false);
  List<NoteModel> get transientNotes =>
      pattern.previewNotes.values.toList(growable: false);
  List<_RecordedLiveEvent> get liveEvents =>
      recordingProcessingGraphApi?.liveEvents.toList(growable: false) ??
      const <_RecordedLiveEvent>[];
  PianoRollStateMachine get stateMachine => controller.stateMachine;
  PianoRollInteractionFamily? get activeInteractionFamily =>
      controller.activeInteractionFamily;

  PianoRollIdleState get idleState =>
      stateMachine.states[PianoRollIdleState]! as PianoRollIdleState;
  PianoRollPointerSessionState get pointerSessionState =>
      stateMachine.states[PianoRollPointerSessionState]!
          as PianoRollPointerSessionState;
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

  void _setModifier(PianoRollModifierKey modifier, bool isPressed) {
    if (stateMachine.data.isModifierPressed(modifier) == isPressed) {
      return;
    }

    if (isPressed) {
      controller.modifierPressed(modifier);
    } else {
      controller.modifierReleased(modifier);
    }
  }

  void setModifiers({bool ctrl = false, bool alt = false, bool shift = false}) {
    _setModifier(PianoRollModifierKey.ctrl, ctrl);
    _setModifier(PianoRollModifierKey.alt, alt);
    _setModifier(PianoRollModifierKey.shift, shift);
  }

  void modifierPressed(PianoRollModifierKey modifier) {
    _setModifier(modifier, true);
  }

  void modifierReleased(PianoRollModifierKey modifier) {
    _setModifier(modifier, false);
  }

  NoteModel addNote({
    required int key,
    required int offset,
    required int length,
    double velocity = 0.75,
    double pan = 0,
  }) {
    final note = NoteModel(
      idAllocator: _testIdAllocator(),
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
    return pattern.notes[id]!;
  }

  PatternNoteOverrideModel? noteOverrideById(Id id) {
    return pattern.noteOverrides[id];
  }

  NoteModel transientNoteById(Id id) {
    return pattern.getPreviewNoteById(id)!;
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

  void syncRenderedViewMetrics() {
    controller.onRenderedViewMetricsChanged(
      viewSize: pianoRollSize,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      keyHeight: viewModel.keyHeight,
      keyValueAtTop: viewModel.keyValueAtTop,
    );
  }

  Offset _localPositionFor({required double key, required double offset}) {
    return Offset(
      timeToPixels(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        viewPixelWidth: pianoRollSize.width,
        time: offset,
      ),
      keyValueToPixels(
        keyValue: key,
        keyValueAtTop: viewModel.keyValueAtTop,
        keyHeight: viewModel.keyHeight,
      ),
    );
  }

  void _seedContentUnderCursor({
    required Offset localPosition,
    Id? noteUnderCursor,
    bool isResize = false,
  }) {
    viewModel.visibleNotes.clear();
    viewModel.visibleResizeAreas.clear();

    if (noteUnderCursor == null) {
      return;
    }

    final ref = PianoRollRenderedNoteRef.real(noteUnderCursor);
    final hitRect = Rect.fromCircle(center: localPosition, radius: 1);
    viewModel.visibleNotes.add(rect: hitRect, metadata: ref);
    if (isResize) {
      viewModel.visibleResizeAreas.add(rect: hitRect, metadata: ref);
    }
  }

  void rawPointerDown({
    required Offset localPosition,
    Id? noteUnderCursor,
    bool isResize = false,
    int buttons = kPrimaryMouseButton,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
    int pointer = 1,
  }) {
    syncRenderedViewMetrics();
    setModifiers(ctrl: ctrl, alt: alt, shift: shift);
    _seedContentUnderCursor(
      localPosition: localPosition,
      noteUnderCursor: noteUnderCursor,
      isResize: isResize,
    );

    controller.pointerDown(
      PointerDownEvent(
        pointer: pointer,
        position: localPosition,
        buttons: buttons,
      ),
    );
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
    final localPosition = _localPositionFor(key: key, offset: offset);
    rawPointerDown(
      localPosition: localPosition,
      noteUnderCursor: noteUnderCursor,
      isResize: isResize,
      buttons: buttons,
      ctrl: ctrl,
      alt: alt,
      shift: shift,
      pointer: pointer,
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
    syncRenderedViewMetrics();
    setModifiers(ctrl: ctrl, alt: alt, shift: shift);
    final localPosition = _localPositionFor(key: key, offset: offset);
    _seedContentUnderCursor(localPosition: localPosition);

    controller.pointerMove(
      PointerMoveEvent(pointer: pointer, position: localPosition),
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
    syncRenderedViewMetrics();
    setModifiers(ctrl: ctrl, alt: alt, shift: shift);
    final localPosition = _localPositionFor(key: key, offset: offset);
    _seedContentUnderCursor(localPosition: localPosition);

    controller.pointerUp(
      PointerUpEvent(pointer: pointer, position: localPosition),
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
    syncRenderedViewMetrics();
    setModifiers(ctrl: ctrl, alt: alt, shift: shift);
    final localPosition = _localPositionFor(key: key, offset: offset);
    _seedContentUnderCursor(localPosition: localPosition);

    controller.pointerUp(
      PointerCancelEvent(pointer: pointer, position: localPosition),
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
    expect(viewModel.hoveredNote, isNull);
    expect(pattern.previewNotes, isEmpty);
    expect(pattern.noteOverrides, isEmpty);
    expect(
      viewModel.selectedNotes.where(
        (noteId) => pattern.resolveNoteById(noteId) == null,
      ),
      isEmpty,
    );
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
        fixture.selectionBoxState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.eraseNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.moveNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.resizeNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.createNoteState.parentState,
        same(fixture.pointerSessionState),
      );
    });

    test('controller dispose is idempotent', () {
      fixture.controller.dispose();
      fixture.controller.dispose();
    });

    test('controller dispose clears in-progress transient preview state', () {
      fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

      expect(fixture.transientNotes, hasLength(1));
      expect(fixture.viewModel.pressedNote, isNotNull);

      fixture.controller.dispose();

      fixture.expectNoActiveTransientState();
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('controller dispose clears an active selection box', () {
      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.controller.dispose();

      fixture.expectNoActiveTransientState();
      expect(fixture.activeInteractionFamily, isNull);
    });

    test(
      'pointer-down gestures classify through the public controller path',
      () {
        final selectionFixture = _PianoRollStateMachineTestFixture.create();
        try {
          selectionFixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
          expect(
            selectionFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.selectionBox),
          );
        } finally {
          selectionFixture.dispose();
        }

        final moveFixture = _PianoRollStateMachineTestFixture.create();
        try {
          final note = moveFixture.addNote(key: 60, offset: 100, length: 48);
          moveFixture.pointerDown(
            key: 60.5,
            offset: 100,
            noteUnderCursor: note.id,
          );
          expect(
            moveFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.moveNotes),
          );
        } finally {
          moveFixture.dispose();
        }

        final resizeFixture = _PianoRollStateMachineTestFixture.create();
        try {
          final note = resizeFixture.addNote(key: 64, offset: 220, length: 96);
          resizeFixture.pointerDown(
            key: 64.5,
            offset: 316,
            noteUnderCursor: note.id,
            isResize: true,
          );
          expect(
            resizeFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.resizeNotes),
          );
        } finally {
          resizeFixture.dispose();
        }

        final createFixture = _PianoRollStateMachineTestFixture.create();
        try {
          createFixture.pointerDown(key: 60.5, offset: 100);
          expect(
            createFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.createNote),
          );
        } finally {
          createFixture.dispose();
        }

        final eraseFixture = _PianoRollStateMachineTestFixture.create();
        try {
          final note = eraseFixture.addNote(key: 60, offset: 100, length: 48);
          eraseFixture.pointerDown(
            key: 60.5,
            offset: 100,
            noteUnderCursor: note.id,
            buttons: kSecondaryMouseButton,
          );
          expect(
            eraseFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.erase),
          );
        } finally {
          eraseFixture.dispose();
        }
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
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.selectionBox),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
      expect(
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('pointer cancel clears the latched route', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));

      fixture.pointerCancel(key: 61.5, offset: 173.8, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
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
      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerMove(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerUp(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('move routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));
      expect(fixture.moveNotesState.sessionData, isNotNull);

      fixture.pointerMove(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));

      fixture.pointerUp(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('resize routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

      fixture.pointerDown(
        key: 60.5,
        offset: 196,
        noteUnderCursor: note.id,
        isResize: true,
      );

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.resizeNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.resizeNotesState));
      expect(fixture.resizeNotesState.sessionData, isNotNull);

      fixture.pointerMove(key: 60.5, offset: 240, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.resizeNotesState));

      fixture.pointerUp(key: 60.5, offset: 240, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('create routing latches a machine route until pointer up', () {
      fixture.pointerDown(key: 60.5, offset: 100);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.createNote),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
      expect(fixture.createNoteState.sessionData, isNotNull);

      fixture.pointerMove(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));

      fixture.pointerUp(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('unsupported raw pointer sessions are ignored', () {
      final localPosition = fixture._localPositionFor(key: 60.5, offset: 100);

      fixture.rawPointerDown(
        localPosition: localPosition,
        buttons: kMiddleMouseButton,
      );

      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.notes, isEmpty);
      fixture.expectNoActiveTransientState();
    });

    test('pointer-session parent stores drag start derived context', () {
      final note = fixture.addNote(key: 64, offset: 220, length: 96);

      fixture.pointerDown(
        key: 64.5,
        offset: 316,
        noteUnderCursor: note.id,
        isResize: true,
      );

      final startContext = fixture.pointerSessionState.startPointerContext;
      expect(startContext, isNotNull);
      expect(startContext!.realNoteUnderCursorId, equals(note.id));
      expect(startContext.isOverResizeHandle, isTrue);
      expect(startContext.key, closeTo(64.5, 0.0001));
      expect(startContext.offset, closeTo(316, 0.0001));
      expect(fixture.pointerSessionState.dragStartRealNoteId, equals(note.id));
      expect(fixture.pointerSessionState.dragStartIsResizeHandle, isTrue);
    });

    test('pointer-session parent updates current derived context on move', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 173.8, alt: true);

      final currentContext = fixture.pointerSessionState.currentPointerContext;
      expect(currentContext, isNotNull);
      expect(currentContext!.key, closeTo(61.5, 0.0001));
      expect(currentContext.offset, closeTo(173.8, 0.0001));
      expect(fixture.pointerSessionState.dragStartKey, closeTo(60.5, 0.0001));
      expect(fixture.pointerSessionState.dragStartOffset, closeTo(100, 0.0001));
    });

    test('raw controller input uses the latest rendered view metrics', () {
      fixture.viewModel.timeView = TimeRange(480, 960);
      fixture.viewModel.keyHeight = 20;
      fixture.viewModel.keyValueAtTop = 72;
      fixture.syncRenderedViewMetrics();

      const localPosition = Offset(240, 60);
      fixture.rawPointerDown(localPosition: localPosition);

      final startContext = fixture.pointerSessionState.startPointerContext;
      expect(startContext, isNotNull);
      expect(
        startContext!.offset,
        closeTo(
          pixelsToTime(
            timeViewStart: 480,
            timeViewEnd: 960,
            viewPixelWidth:
                _PianoRollStateMachineTestFixture.pianoRollSize.width,
            pixelOffsetFromLeft: localPosition.dx,
          ),
          0.0001,
        ),
      );
      expect(
        startContext.key,
        closeTo(
          pixelsToKeyValue(
            keyHeight: 20,
            keyValueAtTop: 72,
            pixelOffsetFromTop: localPosition.dy,
          ),
          0.0001,
        ),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
    });

    test('negative-time create does not initialize a create-note session', () {
      fixture.pointerDown(key: 60.5, offset: -1);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.createNote),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
      expect(fixture.createNoteState.sessionData, isNull);
      expect(fixture.notes, isEmpty);

      fixture.pointerUp(key: 60.5, offset: -1);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
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
      fixture.selectNotes([1004]);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 155);

      final movedNote = fixture.noteById(note.id);
      final movedNoteOverride = fixture.noteOverrideById(note.id);
      final expectedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      expect(movedNote.offset, equals(100));
      expect(movedNote.key, equals(60));
      expect(movedNoteOverride, isNotNull);
      expect(movedNoteOverride!.offset, equals(expectedOffset));
      expect(movedNoteOverride.key, equals(62));

      fixture.pointerUp(key: 62.5, offset: 155);

      fixture.expectSelection(const []);
      fixture.expectNoActiveTransientState();

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));

      fixture.project.redo();
      expect(fixture.noteById(note.id).offset, equals(expectedOffset));
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

    test('modifier changes during drag recompute the move preview', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 155.9);

      final snappedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      expect(fixture.noteOverrideById(note.id)?.offset, equals(snappedOffset));

      fixture.modifierPressed(PianoRollModifierKey.alt);

      expect(fixture.noteOverrideById(note.id)?.offset, equals(155));

      fixture.modifierReleased(PianoRollModifierKey.alt);

      expect(fixture.noteOverrideById(note.id)?.offset, equals(snappedOffset));
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

    test('single-note shift drag duplicates and moves the clone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 100,
        noteUnderCursor: note.id,
        shift: true,
      );

      expect(fixture.notes.length, equals(1));
      expect(fixture.transientNotes, hasLength(1));
      final duplicateId = fixture.transientNotes.single.id;

      fixture.pointerMove(key: 62.5, offset: 200);
      fixture.pointerUp(key: 62.5, offset: 200);

      final original = fixture.noteById(note.id);
      final duplicate = fixture.noteById(duplicateId);
      expect(original.offset, equals(100));
      expect(original.key, equals(60));
      expect(
        duplicate.offset,
        equals(fixture.snappedTime(200, round: true, startTime: 100)),
      );
      expect(duplicate.key, equals(62));

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
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

        expect(fixture.notes.length, equals(2));
        expect(fixture.transientNotes, hasLength(2));
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

        expect(fixture.noteById(note.id).length, equals(96));
        expect(
          fixture.noteOverrideById(note.id)?.length,
          equals(expectedLength),
        );
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
      'synthetic resize hints without a rendered resize hit are ignored',
      () {
        fixture.pointerDown(key: 60.5, offset: 196, isResize: true);

        expect(
          fixture.activeInteractionFamily,
          equals(PianoRollInteractionFamily.createNote),
        );
        expect(
          fixture.stateMachine.currentState,
          same(fixture.createNoteState),
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

        expect(fixture.notes, isEmpty);
        expect(fixture.transientNotes, hasLength(1));
        final note = fixture.transientNotes.single;
        expect(note.key, equals(60));
        expect(note.offset, equals(fixture.snappedTime(145)));
        expect(note.length, equals(48));
        expect(note.velocity, equals(0.25));
        expect(note.pan, equals(0.6));
        expect(fixture.viewModel.pressedNote, equals(note.id));

        fixture.pointerUp(key: 60.9, offset: 145.2);

        fixture.expectNoActiveTransientState();
        expect(fixture.notes, hasLength(1));

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

        expect(fixture.notes, isEmpty);
        final createdNoteId = fixture.transientNotes.single.id;

        fixture.pointerMove(key: 63.5, offset: 173.8, alt: true);
        expect(fixture.notes, isEmpty);
        expect(fixture.transientNoteById(createdNoteId).key, equals(63));
        expect(fixture.transientNoteById(createdNoteId).offset, equals(173));
        fixture.pointerCancel(key: 63.5, offset: 173.8, alt: true);

        final note = fixture.noteById(createdNoteId);
        expect(note.key, equals(63));
        expect(note.offset, equals(173));

        fixture.project.undo();
        expect(fixture.notes, isEmpty);
      },
    );
  });

  group('preview vs commit regression', () {
    test('move preview leaves the real note unchanged until commit', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 155);

      final expectedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      final preview = fixture.noteOverrideById(note.id);

      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
      expect(preview, isNotNull);
      expect(preview!.offset, equals(expectedOffset));
      expect(preview.key, equals(62));
      expect(fixture.viewModel.pressedNote, equals(note.id));

      fixture.pointerUp(key: 62.5, offset: 155);

      expect(fixture.noteById(note.id).offset, equals(expectedOffset));
      expect(fixture.noteById(note.id).key, equals(62));
      fixture.expectNoActiveTransientState();
    });

    test('resize preview leaves the real note unchanged until commit', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

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
      final preview = fixture.noteOverrideById(note.id);

      expect(fixture.noteById(note.id).length, equals(96));
      expect(preview, isNotNull);
      expect(preview!.length, equals(expectedLength));
      expect(fixture.viewModel.pressedNote, equals(note.id));

      fixture.pointerUp(key: 60.5, offset: 250);

      expect(fixture.noteById(note.id).length, equals(expectedLength));
      fixture.expectNoActiveTransientState();
    });

    test('create preview stays transient until commit', () {
      fixture.viewModel.cursorNoteLength = 48;

      fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

      expect(fixture.notes, isEmpty);
      expect(fixture.transientNotes, hasLength(1));
      final createdNoteId = fixture.transientNotes.single.id;

      fixture.pointerMove(key: 63.5, offset: 173.8, alt: true);

      final preview = fixture.transientNoteById(createdNoteId);
      expect(fixture.notes, isEmpty);
      expect(preview.key, equals(63));
      expect(preview.offset, equals(173));
      expect(preview.length, equals(48));
      expect(fixture.viewModel.pressedNote, equals(createdNoteId));

      fixture.pointerUp(key: 63.5, offset: 173.8, alt: true);

      final committed = fixture.noteById(createdNoteId);
      expect(committed.key, equals(63));
      expect(committed.offset, equals(173));
      expect(committed.length, equals(48));
      fixture.expectNoActiveTransientState();
    });

    test(
      'single-note duplicate preview keeps the duplicate transient until commit',
      () {
        final note = fixture.addNote(key: 60, offset: 100, length: 48);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
          shift: true,
        );
        expect(
          fixture.notes.map((note) => note.id).toList(growable: false),
          orderedEquals([note.id]),
        );
        expect(fixture.transientNotes, hasLength(1));
        final duplicateId = fixture.transientNotes.single.id;

        fixture.pointerMove(key: 62.5, offset: 200);

        final expectedOffset = fixture.snappedTime(
          200,
          round: true,
          startTime: 100,
        );
        final movedDuplicatePreview = fixture.transientNoteById(duplicateId);

        expect(fixture.noteById(note.id).offset, equals(100));
        expect(fixture.noteById(note.id).key, equals(60));
        expect(fixture.pattern.noteOverrides, isEmpty);
        expect(movedDuplicatePreview.offset, equals(expectedOffset));
        expect(movedDuplicatePreview.key, equals(62));
        expect(fixture.viewModel.pressedNote, equals(duplicateId));
        expect(
          fixture.viewModel.selectedNotes.nonObservableInner,
          equals({duplicateId}),
        );

        fixture.pointerUp(key: 62.5, offset: 200);

        expect(fixture.noteById(note.id).offset, equals(100));
        expect(fixture.noteById(note.id).key, equals(60));
        expect(fixture.noteById(duplicateId).offset, equals(expectedOffset));
        expect(fixture.noteById(duplicateId).key, equals(62));
        fixture.expectNoActiveTransientState();
      },
    );

    test(
      'selected-group duplicate preview keeps clones transient until commit',
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

        final clonedIds = fixture.viewModel.selectedNotes.nonObservableInner
            .toSet();
        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id}),
        );
        expect(fixture.transientNotes, hasLength(2));

        fixture.pointerMove(key: 61.5, offset: 200);

        final movedDistance =
            fixture.snappedTime(200, round: true, startTime: 100) - 100;
        final previewPositions = clonedIds.map((clonedId) {
          final note = fixture.transientNoteById(clonedId);
          return (key: note.key, offset: note.offset);
        }).toSet();

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));
        expect(fixture.pattern.noteOverrides, isEmpty);
        expect(
          previewPositions,
          equals({
            (key: 61, offset: 100 + movedDistance),
            (key: 65, offset: 180 + movedDistance),
          }),
        );

        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));

        final committedClonePositions = clonedIds.map((clonedId) {
          final note = fixture.noteById(clonedId);
          return (key: note.key, offset: note.offset);
        }).toSet();
        expect(committedClonePositions, equals(previewPositions));
        fixture.expectNoActiveTransientState();
      },
    );
  });
}
