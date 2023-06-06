/*
  Copyright (C) 2023 

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

import 'dart:typed_data';
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';

void _drawNote({
  required Float32List vertices,
  required NoteModel note,
  required int startIndex,
  required int lowestNote,
  required int highestNote,
}) {
  final noteStart = note.offset.toDouble();
  final noteEnd = (note.offset + note.length).toDouble();

  final noteHeight = 1 / (highestNote - lowestNote + 1);
  final noteTop = (highestNote - note.key) / (highestNote - lowestNote + 1);
  final noteBottom = noteTop + noteHeight;

  // Notes are drawn with two triangles, like so:
  //  _______________
  // |``**--..       |
  // |        `**--..|
  // ````````````````

  vertices[startIndex + 0] = noteStart;
  vertices[startIndex + 1] = noteTop;

  vertices[startIndex + 2] = noteEnd;
  vertices[startIndex + 3] = noteTop;

  vertices[startIndex + 4] = noteEnd;
  vertices[startIndex + 5] = noteBottom;

  vertices[startIndex + 6] = noteStart;
  vertices[startIndex + 7] = noteTop;

  vertices[startIndex + 8] = noteEnd;
  vertices[startIndex + 9] = noteBottom;

  vertices[startIndex + 10] = noteStart;
  vertices[startIndex + 11] = noteBottom;
}

/// Caches notes into lists of vertices.
///
/// These vertices are rendered into a unique coordinate space. The Y values are
/// normalized from 0 to 1 where 0 is the top of the highest note and 1 is the
/// bottom of the lowest note, and the X values represent raw time. The clip
/// renderer uses matrix transforms to convert from this coordinate space to
/// pixel coordinates when rendering.
class ClipNotesRenderCache {
  final PatternModel pattern;
  final ID generatorID;

  Float32List? rawVertices;
  Vertices? renderedVertices;

  var lowestNote = 64;
  var highestNote = 64;

  ClipNotesRenderCache({
    required this.pattern,
    required this.generatorID,
  }) {
    update();
  }

  void update() {
    final notes = pattern.notes[generatorID]?.nonObservableInner ?? [];

    rawVertices = Float32List(notes.length * 3 * 2 * 2);

    lowestNote = 0xFFFFFFFF;
    highestNote = 0;

    for (final note in notes) {
      final key = note.key;
      if (key < lowestNote) lowestNote = key;
      if (key > highestNote) highestNote = key;
    }

    int vertexIndex = 0;
    for (final note in notes) {
      _drawNote(
        vertices: rawVertices!,
        note: note,
        startIndex: vertexIndex,
        lowestNote: lowestNote,
        highestNote: highestNote,
      );

      // Each note is two triangles, each made up of three (x, y) pairs.
      vertexIndex += 12;
    }

    renderedVertices = Vertices.raw(
      VertexMode.triangles,
      rawVertices!,
    );
  }
}
