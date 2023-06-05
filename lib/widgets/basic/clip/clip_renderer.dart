/*
  Copyright (C) 2023 Joshua Wade

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

import 'dart:ui';

import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/theme.dart';

import 'clip.dart';

void paintClip({
  required Canvas canvas,
  required Size size,
  required PatternModel pattern,
  required ClipModel clip,
  required double x,
  required double y,
  required double width,
  required double height,
  required bool selected,
  required bool pressed,
}) {
  final color = getBaseColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  final rectPaint = Paint()..color = color;
  final rectStrokePaint = Paint()
    ..color = Theme.grid.accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1),
    const Radius.circular(3),
  );

  canvas.drawRRect(rect, rectPaint);
  canvas.drawRRect(rect, rectStrokePaint);
}
