/*
  Copyright (C) 2025 - 2026 Joshua Wade

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
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class PlayheadLine extends StatelessObserverWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final bool isVisible;
  final Id? editorActiveSequenceId;

  const PlayheadLine({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.isVisible,
    required this.editorActiveSequenceId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    double? transportPositionOverride;
    if (project.engineState != EngineState.running) {
      transportPositionOverride = project.sequence.playbackStartPosition
          .toDouble();
    }

    Id? activeSequenceIdOverride;
    if (project.engineState != EngineState.running) {
      activeSequenceIdOverride = project.sequence.activeTransportSequenceID;
    }

    return Builder(
      builder: (context) {
        return VisualizationBuilder.int(
          config: VisualizationSubscriptionConfig.latestInt(
            'playhead_sequence_id',
          ),
          builder: (context, activeSequenceId, engineTime) {
            return Visibility(
              visible:
                  (activeSequenceIdOverride ?? activeSequenceId) ==
                  editorActiveSequenceId,
              child: VisualizationBuilder.double(
                config: VisualizationSubscriptionConfig.latestDouble(
                  'playhead_position',
                  bufferMode: VisualizationBufferMode.adaptive,
                ),
                builder: (context, transportPosition, engineTime) {
                  return CustomPaint(
                    painter: _PlayheadPainter(
                      repaint: timeViewAnimationController,
                      timeViewStartAnimation: timeViewStartAnimation,
                      timeViewEndAnimation: timeViewEndAnimation,
                      transportPosition:
                          transportPositionOverride ?? transportPosition ?? 0,
                      isVisible:
                          (transportPositionOverride ?? transportPosition) !=
                              null &&
                          isVisible,
                    ),
                  );
                },
              ),
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
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final double transportPosition;
  final bool isVisible;

  _PlayheadPainter({
    required Listenable repaint,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.transportPosition,
    required this.isVisible,
  }) : super(repaint: repaint);

  double get timeViewStart => timeViewStartAnimation.value;
  double get timeViewEnd => timeViewEndAnimation.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isVisible) {
      return;
    }

    final paint = Paint()
      ..color = AnthemTheme.editors.playheadLine
      ..style = PaintingStyle.fill;

    final lineX =
        size.width *
            (transportPosition - timeViewStart) /
            (timeViewEnd - timeViewStart) +
        0.5;
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
      return timeViewStartAnimation != oldDelegate.timeViewStartAnimation ||
          timeViewEndAnimation != oldDelegate.timeViewEndAnimation ||
          transportPosition != oldDelegate.transportPosition ||
          isVisible != oldDelegate.isVisible;
    }
    return true;
  }
}
