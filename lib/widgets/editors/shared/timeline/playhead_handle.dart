/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';

const _playheadHandleSize = Size(15, 15);

Path _getPlayheadHandlePath() {
  final handlePath1 = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, _playheadHandleSize.width, 8),
        Radius.circular(2),
      ),
    );

  final rotatedRectSideLength = sqrt(
    _playheadHandleSize.width * _playheadHandleSize.width / 2,
  );
  final posOffsetForRotate =
      (_playheadHandleSize.width - rotatedRectSideLength) / 2;

  final rRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      posOffsetForRotate,
      4 - posOffsetForRotate,
      rotatedRectSideLength,
      rotatedRectSideLength,
    ),
    Radius.circular(2),
  );
  final handlePath2 = Path()..addRRect(rRect);

  final center = rRect.center;
  final angle = pi / 4; // 45°

  // Build a 4×4 rotation matrix about `center`
  final rotationMatrix = Matrix4.identity()
    ..translate(center.dx, center.dy)
    ..rotateZ(angle)
    ..translate(-center.dx, -center.dy);

  return Path.combine(
    PathOperation.union,
    handlePath1,
    handlePath2.transform(rotationMatrix.storage),
  );
}

final _playheadHandlePath = _getPlayheadHandlePath();

class PlayheadPositioner extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Size timelineSize;
  final double? playheadTimeOverride;
  final bool isStartMarker;

  const PlayheadPositioner({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timelineSize,
    this.playheadTimeOverride,
    this.isStartMarker = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildPlayheadAtPosition(double? playheadPosition) {
      final timeViewStart = timeViewStartAnimation.value;
      final timeViewEnd = timeViewEndAnimation.value;

      final playheadX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: timelineSize.width,
        time: playheadPosition ?? 0,
      );

      return Positioned(
        left: playheadX - (_playheadHandleSize.width) / 2,
        top: timelineSize.height - _playheadHandleSize.height,
        child: CustomPaint(
          size: _playheadHandleSize,
          painter: _PlayheadHandlePainter(
            hide: playheadPosition == null,
            isStartMarker: isStartMarker,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: timeViewAnimationController,
      builder: (context, child) {
        if (playheadTimeOverride != null) {
          return buildPlayheadAtPosition(playheadTimeOverride);
        }

        return VisualizationBuilder.double(
          config: VisualizationSubscriptionConfig.latest('playhead_position'),
          builder: (context, playheadPosition) {
            return buildPlayheadAtPosition(playheadPosition);
          },
        );
      },
    );
  }
}

class _PlayheadHandlePainter extends CustomPainter {
  bool hide;
  bool isStartMarker;

  _PlayheadHandlePainter({this.hide = false, this.isStartMarker = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (hide) {
      return;
    }

    // This is 0xFFFFFFFF with an alpha of 255 * 4 ~/ 10, mixed with the
    // timeline background. Baking it into a single color prevents overlapping
    // markers from looking messy.
    const mainHandleColor = Color(0xFF898989);
    final startMarkerColor = mainHandleColor.withAlpha(150);

    final handlePaint = Paint()
      ..color = isStartMarker ? startMarkerColor : mainHandleColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(_playheadHandlePath, handlePaint);

    if (!isStartMarker) {
      final linePaint = Paint()
        ..color = Color(0xFFD9D9D9)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH((size.width - 1) / 2, 0, 1, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlayheadHandlePainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(_PlayheadHandlePainter oldDelegate) => false;
}
