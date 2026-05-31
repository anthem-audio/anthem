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
import 'package:anthem/widgets/editors/shared/time_range_animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class PlayheadLine extends StatelessObserverWidget {
  final TimeRangeAnimation timeRangeAnimation;
  final bool isVisible;
  final Id? editorActiveSequenceId;

  const PlayheadLine({
    required this.timeRangeAnimation,
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
            final activeSequenceIdForPlayhead =
                activeSequenceIdOverride ?? activeSequenceId;

            return Visibility(
              visible:
                  activeSequenceIdForPlayhead != null &&
                  activeSequenceIdForPlayhead == editorActiveSequenceId,
              child: VisualizationBuilder.double(
                config: VisualizationSubscriptionConfig.latestDouble(
                  'playhead_position',
                  bufferMode: VisualizationBufferMode.adaptive,
                ),
                builder: (context, transportPosition, engineTime) {
                  return CustomPaint(
                    painter: _PlayheadPainter(
                      repaint: timeRangeAnimation.controller,
                      timeRangeAnimation: timeRangeAnimation,
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
  final TimeRangeAnimation timeRangeAnimation;
  final double transportPosition;
  final bool isVisible;

  _PlayheadPainter({
    required Listenable repaint,
    required this.timeRangeAnimation,
    required this.transportPosition,
    required this.isVisible,
  }) : super(repaint: repaint);

  double get timeViewStart => timeRangeAnimation.renderedStart;
  double get timeViewEnd => timeRangeAnimation.renderedEnd;

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
      return timeRangeAnimation != oldDelegate.timeRangeAnimation ||
          transportPosition != oldDelegate.transportPosition ||
          isVisible != oldDelegate.isVisible;
    }
    return true;
  }
}
