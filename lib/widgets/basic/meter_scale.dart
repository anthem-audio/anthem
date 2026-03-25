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

import 'dart:ui';

import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/meter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const defaultMeterScaleTickValues = <double>[
  12.0,
  6.0,
  0.0,
  -6.0,
  -12.0,
  -18.0,
  -24.0,
  -30.0,
  -36.0,
  -42.0,
  -48.0,
  -54.0,
  -60.0,
  -66.0,
];

const defaultMeterScaleLabelValues = <double>[
  0.0,
  -6.0,
  -12.0,
  -18.0,
  -24.0,
  -36.0,
  double.negativeInfinity,
];

class MeterScale extends StatelessWidget {
  final MeterDbToNormalizedPosition dbToNormalizedPosition;
  final List<double> tickValues;
  final List<double> labelValues;
  final double tickWidth;
  final double labelGap;

  const MeterScale({
    super.key,
    this.dbToNormalizedPosition = defaultMeterDbToNormalizedPosition,
    this.tickValues = defaultMeterScaleTickValues,
    this.labelValues = defaultMeterScaleLabelValues,
    this.tickWidth = 3.0,
    this.labelGap = 4.0,
  });

  @visibleForTesting
  static String formatLabel(double db) {
    return formatDb(db);
  }

  @visibleForTesting
  static double positionForDb({
    required double db,
    required double height,
    required MeterDbToNormalizedPosition dbToNormalizedPosition,
  }) {
    final normalized = Meter.dbToNormalizedHeight(db, dbToNormalizedPosition);
    return height - (height * normalized);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MeterScalePainter(
        dbToNormalizedPosition: dbToNormalizedPosition,
        tickValues: tickValues,
        labelValues: labelValues,
        tickWidth: tickWidth,
        labelGap: labelGap,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class MeterScalePainter extends CustomPainter {
  final MeterDbToNormalizedPosition dbToNormalizedPosition;
  final List<double> tickValues;
  final List<double> labelValues;
  final double tickWidth;
  final double labelGap;

  const MeterScalePainter({
    required this.dbToNormalizedPosition,
    required this.tickValues,
    required this.labelValues,
    this.tickWidth = 3.0,
    this.labelGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final color = AnthemTheme.text.main;
    final tickPaint = Paint()..color = color;
    final clampedTickWidth = clampDouble(tickWidth, 0.0, size.width);
    final textStyle = TextStyle(
      color: color,
      fontSize: 10.0,
      fontWeight: .w700,
    );

    for (final db in tickValues) {
      final y = MeterScale.positionForDb(
        db: db,
        height: size.height,
        dbToNormalizedPosition: dbToNormalizedPosition,
      );
      final top = clampDouble(y - 0.5, 0.0, size.height - 1.0);

      canvas.drawRect(
        Rect.fromLTWH(
          size.width - clampedTickWidth,
          top,
          clampedTickWidth,
          1.0,
        ),
        tickPaint,
      );
    }

    for (final db in labelValues) {
      final textPainter = TextPainter(
        text: TextSpan(text: MeterScale.formatLabel(db), style: textStyle),
        textDirection: .ltr,
      )..layout();

      final y = MeterScale.positionForDb(
        db: db,
        height: size.height,
        dbToNormalizedPosition: dbToNormalizedPosition,
      );
      final top = clampDouble(
        y - (textPainter.height / 2),
        0.0,
        size.height - textPainter.height,
      );
      final left = size.width - clampedTickWidth - labelGap - textPainter.width;

      textPainter.paint(canvas, Offset(left, top));
    }
  }

  @override
  bool shouldRepaint(MeterScalePainter oldDelegate) {
    return oldDelegate.dbToNormalizedPosition != dbToNormalizedPosition ||
        !listEquals(oldDelegate.tickValues, tickValues) ||
        !listEquals(oldDelegate.labelValues, labelValues) ||
        oldDelegate.tickWidth != tickWidth ||
        oldDelegate.labelGap != labelGap;
  }
}
