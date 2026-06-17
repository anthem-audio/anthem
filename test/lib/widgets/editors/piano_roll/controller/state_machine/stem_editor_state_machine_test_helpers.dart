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
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/stem_editor_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:mockito/mockito.dart';

import '../../../../../helpers/test_project.dart';

export 'package:anthem/helpers/id.dart';
export 'package:anthem/model/pattern/note.dart';
export 'package:anthem/widgets/editors/piano_roll/controller/state_machine/stem_editor_state_machine.dart';
export 'package:anthem/widgets/editors/piano_roll/view_model.dart';
export 'package:anthem/widgets/editors/shared/helpers/types.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_test/flutter_test.dart';
export '../../../../../helpers/test_project.dart' show testIdAllocator;

class StemEditorStoppedEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();

  @override
  bool get isRunning => false;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;
}

class PianoRollStemEditorStateMachineTestFixture {
  static const stemEditorSize = Size(960, 120);

  final ProjectModel project;
  final PatternModel pattern;
  final PianoRollViewModel viewModel;
  final PianoRollStemEditorStateMachine stateMachine;

  PianoRollStemEditorStateMachineTestFixture._({
    required this.project,
    required this.pattern,
    required this.viewModel,
    required this.stateMachine,
  });

  factory PianoRollStemEditorStateMachineTestFixture.create() {
    final project = ProjectModel.create()..engine = StemEditorStoppedEngine();
    final pattern = PatternModel(
      idAllocator: testIdAllocator(),
      name: 'Pattern 1',
    );
    project.sequence.patterns[pattern.id] = pattern;
    project.sequence.activePatternID = pattern.id;
    project.sequence.activeTrackID = null;

    final viewModel = PianoRollViewModel(
      keyHeight: 14.0,
      keyValueAtTop: 63.95,
      timeRange: TimeRange(0, 3072),
    );

    final stateMachine = PianoRollStemEditorStateMachine.create(
      project: project,
      viewModel: viewModel,
    );

    return PianoRollStemEditorStateMachineTestFixture._(
      project: project,
      pattern: pattern,
      viewModel: viewModel,
      stateMachine: stateMachine,
    );
  }

  List<NoteModel> get notes => pattern.notes.values.toList(growable: false);
  List<NoteModel> get transientNotes =>
      pattern.previewNotes.values.toList(growable: false);

  PianoRollStemIdleState get idleState =>
      stateMachine.states[PianoRollStemIdleState]! as PianoRollStemIdleState;
  PianoRollStemPointerSessionState get pointerSessionState =>
      stateMachine.states[PianoRollStemPointerSessionState]!
          as PianoRollStemPointerSessionState;
  PianoRollStemEditState get editState =>
      stateMachine.states[PianoRollStemEditState]! as PianoRollStemEditState;

  NoteModel addNote({
    int key = 60,
    double velocity = 0.8,
    int length = 96,
    int offset = 120,
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

  NoteModel addPreviewNote({
    int key = 60,
    double velocity = 0.8,
    int length = 96,
    int offset = 120,
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
    pattern.addPreviewNote(note);
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

  PianoRollStemEditorPointerEvent eventAt({
    double offset = 120,
    double normalizedY = 0.25,
    int pointer = 1,
  }) {
    return PianoRollStemEditorPointerEvent(
      offset: offset,
      normalizedY: normalizedY,
      viewSize: stemEditorSize,
      pointer: pointer,
    );
  }

  void pointerDown({
    double offset = 120,
    double normalizedY = 0.25,
    int pointer = 1,
  }) {
    stateMachine.onPointerDown(
      eventAt(offset: offset, normalizedY: normalizedY, pointer: pointer),
    );
  }

  void pointerMove({
    double offset = 120,
    double normalizedY = 0.25,
    int pointer = 1,
  }) {
    stateMachine.onPointerMove(
      eventAt(offset: offset, normalizedY: normalizedY, pointer: pointer),
    );
  }

  void pointerUp({
    double offset = 120,
    double normalizedY = 0.25,
    int pointer = 1,
  }) {
    stateMachine.onPointerUp(
      eventAt(offset: offset, normalizedY: normalizedY, pointer: pointer),
    );
  }

  void dispose() {
    stateMachine.dispose();
  }
}
