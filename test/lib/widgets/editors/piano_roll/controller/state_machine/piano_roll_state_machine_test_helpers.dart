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
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
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

import '../../../../../helpers/test_project.dart';

export 'package:anthem/engine_api/messages/messages.dart';
export 'package:anthem/helpers/id.dart';
export 'package:anthem/logic/service_registry.dart';
export 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
export 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
export 'package:anthem/widgets/editors/piano_roll/helpers.dart';
export 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
export 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
export 'package:anthem/widgets/editors/shared/helpers/types.dart';
export 'package:flutter/gestures.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_test/flutter_test.dart';
export '../../../../../helpers/test_project.dart' show testIdAllocator;

class StoppedEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();

  @override
  bool get isRunning => false;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;
}

class RecordedLiveEvent {
  final Id liveEventProviderNodeId;
  final Object event;

  const RecordedLiveEvent({
    required this.liveEventProviderNodeId,
    required this.event,
  });
}

class RecordingProcessingGraphApi implements ProcessingGraphApi {
  final List<RecordedLiveEvent> liveEvents = [];

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: true, results: []);

  @override
  Future<void> publish() async {}

  @override
  Future<String> getPluginState(Id nodeId) async => '';

  @override
  void openPluginWindow(Id nodeId) {}

  @override
  void sendLiveEvent(Id liveEventProviderNodeId, Object event) {
    liveEvents.add(
      RecordedLiveEvent(
        liveEventProviderNodeId: liveEventProviderNodeId,
        event: event,
      ),
    );
  }

  @override
  void setPluginParameterValue(Id nodeId, int controlPortId, double value) {}

  @override
  void setPluginState(Id nodeId, String state) {}
}

class NoopSequencerApi implements SequencerApi {
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

class RunningEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();
  final RecordingProcessingGraphApi _processingGraphApi;
  final NoopSequencerApi _sequencerApi = NoopSequencerApi();
  bool _isRunning = false;

  RunningEngine(this._processingGraphApi);

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

class TrackIds {
  static const instrument = 1;
  static const master = 2;
}

TrackModel makeTrack(Id id, String name, TrackType type) {
  return makeTestTrack(id, name, type);
}

class PianoRollStateMachineTestFixture {
  static const pianoRollSize = Size(960, 240);
  static const liveEventProviderNodeId = 3;

  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final ProjectViewModel projectViewModel;
  final ProjectController projectController;
  final PianoRollController controller;
  final PatternModel pattern;
  final Id trackId;
  final RecordingProcessingGraphApi? recordingProcessingGraphApi;
  final RunningEngine? runningEngine;

  PianoRollStateMachineTestFixture._({
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

  factory PianoRollStateMachineTestFixture.create({
    bool enableLiveEvents = false,
  }) {
    final project = createTestProject(
      tracks: const [
        TestProjectTrack(id: TrackIds.instrument, name: 'Instrument'),
        TestProjectTrack(
          id: TrackIds.master,
          name: 'Master',
          isMasterTrack: true,
        ),
      ],
      trackOrder: const [TrackIds.instrument],
      sendTrackOrder: const [TrackIds.master],
    );
    final recordingProcessingGraphApi = enableLiveEvents
        ? RecordingProcessingGraphApi()
        : null;
    final runningEngine = enableLiveEvents
        ? RunningEngine(recordingProcessingGraphApi!)
        : null;
    project.engine = enableLiveEvents ? runningEngine! : StoppedEngine();
    if (enableLiveEvents) {
      project
              .tracks[TrackIds.instrument]!
              .requireProcessing
              .liveEventProviderNodeId =
          liveEventProviderNodeId;
    }

    final pattern = PatternModel(
      idAllocator: testIdAllocator(),
      name: 'Pattern 1',
    );
    project.sequence.patterns = AnthemObservableMap.of({pattern.id: pattern});
    project.sequence.setActivePattern(pattern.id);
    project.sequence.setActiveTrack(TrackIds.instrument);

    final viewModel = PianoRollViewModel(
      keyHeight: 14.0,
      // Hack: cuts off the top horizontal line. Otherwise the default view looks off
      keyValueAtTop: 63.95,
      timeRange: TimeRange(0, 3072),
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
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
      keyHeight: viewModel.keyHeight,
      keyValueAtTop: viewModel.keyValueAtTop,
    );

    return PianoRollStateMachineTestFixture._(
      project: project,
      viewModel: viewModel,
      projectViewModel: projectViewModel,
      projectController: projectController,
      controller: controller,
      pattern: pattern,
      trackId: TrackIds.instrument,
      recordingProcessingGraphApi: recordingProcessingGraphApi,
      runningEngine: runningEngine,
    );
  }

  List<NoteModel> get notes => pattern.notes.values.toList(growable: false);
  List<NoteModel> get transientNotes =>
      pattern.previewNotes.values.toList(growable: false);
  List<RecordedLiveEvent> get liveEvents =>
      recordingProcessingGraphApi?.liveEvents.toList(growable: false) ??
      const <RecordedLiveEvent>[];
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
      idAllocator: testIdAllocator(),
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
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
    );
  }

  int snappedTime(int rawTime, {bool round = false, int startTime = 0}) {
    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: divisionChanges(),
      ceil: false,
      round: round,
      startTime: startTime,
    );
  }

  int ceilingSnappedTime(int rawTime) {
    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: divisionChanges(),
      ceil: true,
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
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
      keyHeight: viewModel.keyHeight,
      keyValueAtTop: viewModel.keyValueAtTop,
    );
  }

  Offset localPositionFor({required double key, required double offset}) {
    return Offset(
      timeToPixels(
        timeViewStart: viewModel.timeRange.start,
        timeViewEnd: viewModel.timeRange.end,
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

  void _seedHitTestTarget({
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
    _seedHitTestTarget(
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
    final localPosition = localPositionFor(key: key, offset: offset);
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

  void rawHover({
    required Offset localPosition,
    Id? noteUnderCursor,
    bool isResize = false,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    syncRenderedViewMetrics();
    setModifiers(ctrl: ctrl, alt: alt, shift: shift);
    _seedHitTestTarget(
      localPosition: localPosition,
      noteUnderCursor: noteUnderCursor,
      isResize: isResize,
    );

    controller.onHover(PointerHoverEvent(position: localPosition));
  }

  void hover({
    required double key,
    required double offset,
    Id? noteUnderCursor,
    bool isResize = false,
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    rawHover(
      localPosition: localPositionFor(key: key, offset: offset),
      noteUnderCursor: noteUnderCursor,
      isResize: isResize,
      ctrl: ctrl,
      alt: alt,
      shift: shift,
    );
  }

  void exit({double key = 60, double offset = 0}) {
    syncRenderedViewMetrics();
    final localPosition = localPositionFor(key: key, offset: offset);

    controller.onExit(PointerExitEvent(position: localPosition));
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
    final localPosition = localPositionFor(key: key, offset: offset);
    _seedHitTestTarget(localPosition: localPosition);

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
    final localPosition = localPositionFor(key: key, offset: offset);
    _seedHitTestTarget(localPosition: localPosition);

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
    final localPosition = localPositionFor(key: key, offset: offset);
    _seedHitTestTarget(localPosition: localPosition);

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
    ServiceRegistry.clipboard.clear();
    ServiceRegistry.mainWindowController.clearAllCursorOverrides();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}
