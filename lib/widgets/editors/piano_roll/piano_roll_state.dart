/*
  Copyright (C) 2021 Joshua Wade

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

part of 'piano_roll_cubit.dart';

@immutable
class PianoRollState {
  final int projectID;
  final Optional<PatternModel> pattern;
  final int ticksPerQuarter;
  final Optional<int> activeInstrumentID;
  final List<LocalNote> notes;

  const PianoRollState({
    required this.projectID,
    required this.pattern,
    required this.ticksPerQuarter,
    required this.activeInstrumentID,
    required this.notes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PianoRollState &&
          other.pattern == pattern &&
          other.ticksPerQuarter == ticksPerQuarter &&
          other.activeInstrumentID == activeInstrumentID &&
          other.notes == notes);

  @override
  int get hashCode =>
      pattern.hashCode ^
      ticksPerQuarter.hashCode ^
      activeInstrumentID.hashCode ^
      notes.hashCode;

  PianoRollState copyWith({
    int? projectID,
    Optional<PatternModel>? pattern,
    int? ticksPerQuarter,
    Optional<int>? activeInstrumentID,
    List<LocalNote>? notes,
  }) {
    return PianoRollState(
      projectID: projectID ?? this.projectID,
      pattern: pattern ?? this.pattern,
      ticksPerQuarter: ticksPerQuarter ?? this.ticksPerQuarter,
      activeInstrumentID: activeInstrumentID ?? this.activeInstrumentID,
      notes: notes ?? this.notes,
    );
  }
}

// A list of these is used by the piano roll. The list is updated when the Rust
// note list updates.
class LocalNote implements NoteModel {
  @override
  late int id;
  @override
  late int key;
  @override
  late int length;
  @override
  late int offset;
  @override
  late int velocity;

  LocalNote({
    required this.id,
    required this.key,
    required this.length,
    required this.offset,
    required this.velocity,
  });

  LocalNote.fromNote(NoteModel note) {
    id = note.id;
    key = note.key;
    length = note.length;
    offset = note.offset;
    velocity = note.velocity;
  }
}
