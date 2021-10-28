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

import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

class ClipNotes extends StatelessWidget {
  final List<Note> notes;
  final double timeViewStart;
  final double ticksPerPixel;

  const ClipNotes({
    Key? key,
    required this.notes,
    required this.timeViewStart,
    required this.ticksPerPixel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ClipNotesPainter(
        notes: this.notes,
        timeViewStart: this.timeViewStart,
        ticksPerPixel: this.ticksPerPixel,
      ),
    );
  }
}

class ClipNotesPainter extends CustomPainter {
  final List<Note> notes;
  final double timeViewStart;
  final double ticksPerPixel;

  ClipNotesPainter({
    required this.notes,
    required this.timeViewStart,
    required this.ticksPerPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print(size);
    canvas.drawRect(Rect.fromPoints(Offset(0, 0), Offset(10, 10)),
        Paint()..color = Color(0xFF00FF00));
  }

  @override
  bool shouldRepaint(ClipNotesPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.timeViewStart != timeViewStart;
  }
}
