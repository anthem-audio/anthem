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

import 'package:anthem/model/note.dart';
import 'package:flutter/widgets.dart';

class ClipNotes extends StatelessWidget {
  final List<NoteModel> notes;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  const ClipNotes({
    Key? key,
    required this.notes,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ClipNotesPainter(
        notes: notes,
        timeViewStart: timeViewStart,
        ticksPerPixel: ticksPerPixel,
        color: color,
      ),
    );
  }
}

class ClipNotesPainter extends CustomPainter {
  final List<NoteModel> notes;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  ClipNotesPainter({
    required this.notes,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    var bottom = notes[0].key;
    var top = notes[0].key;
    for (var note in notes) {
      if (note.key < bottom) bottom = note.key;
      if (note.key > top) top = note.key;
    }

    bottom--;

    if (top - bottom < 12) {
      top += ((top - bottom) / 2).ceil();
      bottom -= ((top - bottom) / 2).floor();
    }

    final keyHeight = top - bottom;
    final yPixelsPerKey = size.height / keyHeight;

    for (var note in notes) {
      final left = (note.offset / ticksPerPixel).floorToDouble();
      final top =
          (size.height - (note.key - bottom) * yPixelsPerKey).floorToDouble();
      final width = (note.length / ticksPerPixel).ceilToDouble();
      final height = (yPixelsPerKey).ceilToDouble();

      final topLeft =
          Offset(left.clamp(0, size.width), top.clamp(0, size.height));
      final bottomRight = Offset((left + width).clamp(0, size.width),
          (top + height).clamp(0, size.height));

      final noteSize = bottomRight - topLeft;
      if (noteSize.dx == 0 || noteSize.dy == 0) continue;

      canvas.drawRect(
          Rect.fromPoints(topLeft, bottomRight), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(ClipNotesPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.ticksPerPixel != ticksPerPixel;
  }
}
