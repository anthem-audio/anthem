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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconstruct creates notes with new IDs and adjusted offsets', () {
    var nextId = 100;
    final idAllocator = ProjectEntityIdAllocator.test(() => nextId++);
    var nextSourceId = 1;
    final sourceIdAllocator = ProjectEntityIdAllocator.test(
      () => nextSourceId++,
    );
    final firstSourceNote = NoteModel(
      idAllocator: sourceIdAllocator,
      key: 60,
      velocity: 0.75,
      length: 24,
      offset: 48,
      pan: 0.1,
    );
    final secondSourceNote = NoteModel(
      idAllocator: sourceIdAllocator,
      key: 64,
      velocity: 0.5,
      length: 96,
      offset: 72,
      pan: -0.25,
    );
    final content = NotesClipboardContent(
      anchorOffset: 48,
      notes: [firstSourceNote, secondSourceNote],
    );

    final notes = content.reconstruct(
      idAllocator: idAllocator,
      newAnchorOffset: 192,
    );

    expect(notes, hasLength(2));

    expect(notes[0].id, 100);
    expect(notes[0].key, 60);
    expect(notes[0].velocity, 0.75);
    expect(notes[0].length, 24);
    expect(notes[0].offset, 192);
    expect(notes[0].pan, 0.1);

    expect(notes[1].id, 101);
    expect(notes[1].key, 64);
    expect(notes[1].velocity, 0.5);
    expect(notes[1].length, 96);
    expect(notes[1].offset, 216);
    expect(notes[1].pan, -0.25);
  });

  test('constructor stores note JSON with a caller-supplied anchor', () {
    var nextId = 1;
    final idAllocator = ProjectEntityIdAllocator.test(() => nextId++);
    final note = NoteModel(
      idAllocator: idAllocator,
      key: 72,
      velocity: 0.6,
      length: 12,
      offset: 32,
      pan: 0,
    );

    final content = NotesClipboardContent(anchorOffset: 24, notes: [note]);

    note.offset = 64;

    expect(content.anchorOffset, 24);
    expect(content.serializedNotes.single['offset'], 32);
    expect(content.serializedNotes.single['key'], 72);
  });
}
