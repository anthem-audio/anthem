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

// A list of these is used by the piano roll. The list is updated when the Rust
// note list updates.
class LocalNote implements Note {
  late int _id;
  late int _key;
  late int _length;
  late int _offset;
  late int _velocity;

  LocalNote({required int id, required int key, required int length, required int offset, required int velocity}) {
    this._id = id;
    this._key = key;
    this._length = length;
    this._offset = offset;
    this._velocity = velocity;
  }

  LocalNote.fromNote(Note note) {
    this._id = note.id;
    this._key = note.key;
    this._length = note.length;
    this._offset = note.offset;
    this._velocity = note.velocity;
  }

  @override
  int get id => this._id;

  @override
  int get key => this._key;

  @override
  int get length => this._length;

  @override
  int get offset => this._offset;

  @override
  int get velocity => this._velocity;
}
