/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:flutter/widgets.dart';

import '../mobx_custom_painter.dart';

class ClipNotes extends StatelessWidget {
  final PatternModel pattern;
  final ID? generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  const ClipNotes({
    Key? key,
    required this.pattern,
    this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaintObserver(
      painter: _ClipNotesPainter(
        pattern: pattern,
        generatorID: generatorID,
        timeViewStart: timeViewStart,
        ticksPerPixel: ticksPerPixel,
        color: color,
      ),
    );
  }
}

class _ClipNotesPainter extends CustomPainterObserver {
  final PatternModel pattern;
  final ID? generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  _ClipNotesPainter({
    required this.pattern,
    this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    final noteLists = generatorID == null
        ? pattern.notes.values.toList()
        : [pattern.notes[generatorID!]!];

    if (noteLists.isEmpty) return;

    int? nullableBottom;
    int? nullableTop;

    for (var notes in noteLists) {
      for (var note in notes) {
        if (nullableBottom == null || nullableTop == null) {
          nullableBottom = note.key;
          nullableTop = note.key;
          continue;
        }

        if (note.key < nullableBottom) nullableBottom = note.key;
        if (note.key > nullableTop) nullableTop = note.key;
      }
    }

    if (nullableBottom == null || nullableTop == null) return;

    int bottom = nullableBottom;
    int top = nullableTop;

    bottom--;

    if (top - bottom < 12) {
      top += ((top - bottom) / 2).ceil();
      bottom -= ((top - bottom) / 2).floor();
    }

    final keyHeight = top - bottom;
    final yPixelsPerKey = size.height / keyHeight;

    for (final noteList in noteLists) {
      for (final note in noteList) {
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
  }

  @override
  bool shouldRepaint(_ClipNotesPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.generatorID != generatorID ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.ticksPerPixel != ticksPerPixel ||
        oldDelegate.color != color ||
        super.shouldRepaint(oldDelegate);
  }
}
