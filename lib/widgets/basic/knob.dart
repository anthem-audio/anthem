/*
  Copyright (C) 2024 Joshua Wade

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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Knob extends StatelessWidget {
  final double? width;
  final double? height;
  final KnobType type;

  final double value;

  const Knob({
    super.key,
    this.width,
    this.height,
    this.type = KnobType.normal,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _KnobPainter(value: value, type: type),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double value;
  final KnobType type;

  _KnobPainter({required this.value, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final trackBorderPaint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final trackFillPaint = Paint()
      ..color = const Color(0xFF28D1AA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    final arcRect =
        Rect.fromCircle(center: center, radius: size.width / 2 - 1.5);

    final startAngle = switch (type) {
      KnobType.normal => pi / 2,
      KnobType.pan => -pi / 2,
    };

    final valueAngle = switch (type) {
      KnobType.normal => value * pi * 2,
      KnobType.pan => value * pi,
    };

    // Inner arc
    canvas.drawArc(arcRect, startAngle, valueAngle, false, trackFillPaint);

    // Borders
    canvas.drawCircle(center, size.width / 2, trackBorderPaint);
    canvas.drawCircle(center, size.width / 2 - 3, trackBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum KnobType {
  normal,
  pan,
}
