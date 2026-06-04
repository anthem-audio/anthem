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

part of 'clipboard_data.dart';

final class NotesClipboardContent extends ClipboardContent {
  final int anchorOffset;
  final List<Map<String, dynamic>> serializedNotes;

  NotesClipboardContent({
    required this.anchorOffset,
    required Iterable<NoteModel> notes,
  }) : serializedNotes = notes.map((note) => note.toJson()).toList();

  List<NoteModel> reconstruct({
    required ProjectEntityIdAllocator idAllocator,
    required int newAnchorOffset,
  }) {
    return serializedNotes
        .map((noteJson) {
          final note = NoteModel.fromJson(noteJson);

          note.id = idAllocator.allocateSequenceNoteId();
          note.offset = note.offset - anchorOffset + newAnchorOffset;

          return note;
        })
        .toList(growable: false);
  }
}
