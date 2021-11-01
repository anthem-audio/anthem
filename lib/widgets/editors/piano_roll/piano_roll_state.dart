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
  final Pattern? pattern;
  final int ticksPerQuarter;
  final int? activeInstrumentID;
  final List<LocalNote> notes;

  PianoRollState({
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
}

// Wraps a note and contains additional state that doesn't need to be sent to
// the Rust side
class LocalNote {
  late Note model;
  int? transientOffset;
  int? transientKey;
  int? transientLength;

  LocalNote(
      {required Note note,
      int? transientOffset,
      int? transientKey,
      int? transientLength}) {
    model = note;
    this.transientKey = transientKey;
    this.transientOffset = transientOffset;
    this.transientLength = transientLength;
  }

  int getOffset() {
    return transientOffset ?? model.offset;
  }

  int getKey() {
    return transientKey ?? model.key;
  }

  int getLength() {
    return transientLength ?? model.length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.model == model &&
          other.transientKey == transientKey &&
          other.transientOffset == transientOffset &&
          other.transientLength == transientLength);
}
