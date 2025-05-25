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

import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/widgets.dart';

class Playhead extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final bool isVisible;

  const Playhead({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.isVisible,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return VisualizationBuilder(
          config: VisualizationSubscriptionConfig.latest('playhead'),
          builder: (context, transportPosition) {
            return AnimatedBuilder(
              animation: timeViewAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PlayheadPainter(
                    timeViewStart: timeViewStartAnimation.value,
                    timeViewEnd: timeViewEndAnimation.value,
                    transportPosition: transportPosition,
                    isVisible: isVisible,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Draws the current position of the transport as a vertical bar, to be
/// overlayed on an editor canvas.
class _PlayheadPainter extends CustomPainter {
  final double timeViewStart;
  final double timeViewEnd;
  final double transportPosition;
  final bool isVisible;

  _PlayheadPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.transportPosition,
    required this.isVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isVisible) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..style = PaintingStyle.fill;

    final lineX =
        size.width *
        (transportPosition - timeViewStart) /
        (timeViewEnd - timeViewStart);
    final lineWidth = 1.0;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(lineX - lineWidth / 2, 0, lineWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _PlayheadPainter) {
      return timeViewStart != oldDelegate.timeViewStart ||
          timeViewEnd != oldDelegate.timeViewEnd ||
          transportPosition != oldDelegate.transportPosition ||
          isVisible != oldDelegate.isVisible;
    }
    return true;
  }
}
