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
      painterBuilder: () => _ClipNotesPainter(
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
    pattern.clipNotesUpdateSignal;

    final cacheItems = generatorID != null
        ? [pattern.clipNotesRenderCache[generatorID]!]
        : pattern.clipNotesRenderCache.values;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final cacheItem in cacheItems) {
      if (cacheItem.renderedVertices == null) continue;

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
