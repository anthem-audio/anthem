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

part of 'piano_roll_cubit.dart';

@freezed
class PianoRollState with _$PianoRollState {

  factory PianoRollState({
    required int projectID,
    int? patternID,
    required int ticksPerQuarter,
    int? activeInstrumentID,
    required List<LocalNote> notes,
    required double keyHeight,
    required double keyValueAtTop,
    required int lastContent, // tick position of the last note end
  }) = _PianoRollState;
}

// A list of these is used by the piano roll. The list is updated when the
// model note list updates.
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

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
