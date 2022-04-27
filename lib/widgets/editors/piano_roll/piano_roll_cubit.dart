/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'piano_roll_state.dart';
part 'piano_roll_cubit.freezed.dart';

class PianoRollCubit extends Cubit<PianoRollState> {
  late final ProjectModel project;

  PianoRollCubit({required ID projectID})
      : super(
          (() {
            final project = Store.instance.projects[projectID]!;

            return PianoRollState(
              projectID: projectID,
              ticksPerQuarter: project.song.ticksPerQuarter,
              notes: const [],
              keyHeight: 20,
              keyValueAtTop:
                  63.95, // Hack: cuts off the top horizontal line. Otherwise the default view looks off
              lastContent: project.song.ticksPerQuarter *
                  // TODO: Use actual project time signature
                  4 * // 4/4 time signature
                  8, // 8 bars
            );
          })(),
        ) {
    project = Store.instance.projects[projectID]!;
    project.stateChangeStream.listen(_onModelChanged);
  }

  List<LocalNote> _getLocalNotes(ID patternID, ID generatorID) {
    return (project.song.patterns[patternID]!.notes[generatorID] ?? [])
        .map((modelNote) => LocalNote.fromNote(modelNote))
        .toList();
  }

  _onModelChanged(List<StateChange> changes) {
    var updateActivePattern = false;
    var updateActiveGenerator = false;

    for (final change in changes) {
      if (change is ActivePatternChanged ||
          change is NoteAdded ||
          change is NoteDeleted ||
          change is NoteMoved ||
          change is NoteResized ||
          change is ActiveGeneratorChanged) {
        updateActivePattern = true;
      }

      if (change is ActiveGeneratorChanged) {
        updateActiveGenerator = true;
      }
    }

    PianoRollState? newState;

    if (updateActivePattern) {
      final patternID = project.song.activePatternID;
      final pattern = project.song.patterns[patternID];

      final List<LocalNote> notes =
          pattern == null || state.activeInstrumentID == null
              ? []
              : _getLocalNotes(pattern.id, state.activeInstrumentID!);

      newState = (newState ?? state).copyWith(
        patternID: patternID,
        notes: notes,
        lastContent: pattern?.getWidth(
              barMultiple: 4,
              minPaddingInBarMultiples: 4,
            ) ??
            state.ticksPerQuarter * 4 * 8,
      );
    }

    if (updateActiveGenerator) {
      final patternID = (newState ?? state).patternID;
      final pattern = project.song.patterns[patternID];

      final List<LocalNote> notes = state.patternID == null ||
              project.song.activeGeneratorID == null
          ? []
          : _getLocalNotes(state.patternID!, project.song.activeGeneratorID!);

      newState = (newState ?? state).copyWith(
        activeInstrumentID: project.song.activeGeneratorID,
        notes: notes,
        lastContent: pattern?.getWidth(
              barMultiple: 4,
              minPaddingInBarMultiples: 4,
            ) ??
            state.ticksPerQuarter * 4 * 8,
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }

  NoteModel? _getNote(ID? instrumentID, ID noteID) {
    final pattern = project.song.patterns[state.patternID];
    final noteList = pattern?.notes[instrumentID];
    NoteModel? note;
    try {
      note = noteList?.firstWhere((note) => note.id == noteID);
    } catch (ex) {
      note = null;
    }
    return note;
  }

  void addNote({
    required ID? instrumentID,
    required int key,
    required int velocity,
    required int length,
    required int offset,
  }) {
    if (state.patternID == null || instrumentID == null) {
      return;
    }

    final data = {};

    data["id"] = getID();
    data["key"] = key;
    data["velocity"] = velocity;
    data["length"] = length;
    data["offset"] = offset;

    project.execute(AddNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      note: NoteModel(
        key: key,
        velocity: velocity,
        length: length,
        offset: offset,
      ),
    ));
  }

  void removeNote({required ID? instrumentID, required ID noteID}) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    project.execute(DeleteNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      note: note,
    ));
  }

  void moveNote({
    required ID? instrumentID,
    required ID noteID,
    required int key,
    required int offset,
  }) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    return project.execute(MoveNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      noteID: noteID,
      oldKey: note.key,
      newKey: key,
      oldOffset: note.offset,
      newOffset: offset,
    ));
  }

  void resizeNote({
    required ID? instrumentID,
    required ID noteID,
    required int length,
  }) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    return project.execute(ResizeNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      noteID: noteID,
      oldLength: note.length,
      newLength: length,
    ));
  }

  // Used to affect the notes in the view model without changing the main
  // model. This is used for in-progress operations. For example, if the user
  // selects a group of notes, presses mouse down, and moves the notes around,
  // mutateLocalNotes() is called. On mouse up, moveNote is called above. This
  // is useful because moveNote pushes a command to the undo/redo queue,
  // whereas this does not.
  //
  // It might be possible to handle this at the app model level. This would
  // have the advantage of allowing in-progress updates to affect other things
  // like clip renderers and property panels, but I haven't thought of a way to
  // generalize a fix for the undo/redo issue. We can use journal pages, but we
  // also don't want pages to contain every in-progress action the user
  // performed (i.e. if the user moves the notes around a lot before releasing
  // the mouse, we still want a journal page that just moves the notes from the
  // start position to the end position). It's possible to fix this on a case-
  // by-case basis but I think that would result in messier code.
  //
  // Until we can come up with a solution to the above, I think it's best to
  // keep this solution of mutating the local view model until we're ready to
  // commit.
  void mutateLocalNotes(
      {required int? instrumentID,
      required Function(List<LocalNote> notes) mutator}) {
    if (state.patternID == null || instrumentID == null) {
      return;
    }

    final pattern = project.song.patterns[state.patternID]!;

    final newNotes = [...state.notes];

    mutator(newNotes);

    emit(state.copyWith(
      notes: newNotes,
      lastContent: pattern.getWidth(
        barMultiple: 4,
        minPaddingInBarMultiples: 4,
      ),
    ));
  }

  void setKeyHeight(double newKeyHeight) {
    emit(state.copyWith(keyHeight: newKeyHeight));
  }

  void setKeyValueAtTop(double newKeyValueAtTop) {
    emit(state.copyWith(keyValueAtTop: newKeyValueAtTop));
  }
}
