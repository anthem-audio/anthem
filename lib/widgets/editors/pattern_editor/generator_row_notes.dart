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
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:flutter/widgets.dart';

class GeneratorRowNotes extends StatelessWidget {
  final PatternModel pattern;
  final Id generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  const GeneratorRowNotes({
    super.key,
    required this.pattern,
    required this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaintObserver(
      painterBuilder:
          () => _GeneratorRowNotesPainter(
            pattern: pattern,
            generatorID: generatorID,
            timeViewStart: timeViewStart,
            ticksPerPixel: ticksPerPixel,
            color: color,
          ),
    );
  }
}

class _GeneratorRowNotesPainter extends CustomPainterObserver {
  final PatternModel pattern;
  final Id? generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  _GeneratorRowNotesPainter({
    required this.pattern,
    this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    pattern.clipNotesUpdateSignal.value;

    final cacheItem = pattern.clipNotesRenderCache[generatorID]!;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (cacheItem.renderedVertices == null) return;

    canvas.save();

    final dist = cacheItem.highestNote - cacheItem.lowestNote;
    final notePadding = size.height * (0.4 - dist * 0.05).clamp(0.1, 0.4);

    final clipScaleFactor = 1 / ticksPerPixel;

    canvas.translate(-timeViewStart * clipScaleFactor, notePadding);
    canvas.scale(clipScaleFactor, size.height - notePadding * 2);

    canvas.drawVertices(
      cacheItem.renderedVertices!,
      BlendMode.srcOver,
      Paint()..color = color,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GeneratorRowNotesPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.generatorID != generatorID ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.ticksPerPixel != ticksPerPixel ||
        oldDelegate.color != color ||
        super.shouldRepaint(oldDelegate);
  }
}
