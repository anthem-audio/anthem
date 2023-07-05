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

import 'dart:ui' as ui;

import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/smooth.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:provider/provider.dart';

class AutomationEditorContentRenderer extends StatelessObserverWidget {
  final double timeViewStart;
  final double timeViewEnd;

  const AutomationEditorContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final pattern = project.song.patterns[project.song.activePatternID];

    return ShaderBuilder(
      assetKey: 'assets/shaders/automation_curve.frag',
      (context, shader, child) => CustomPaintObserver(
        painterBuilder: () => AutomationEditorPainter(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          ticksPerQuarter: project.song.ticksPerQuarter,
          project: project,
          pattern: pattern,
          shader: shader,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
        isComplex: true,
      ),
    );
  }
}

class AutomationEditorPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final ProjectModel project;
  final PatternModel? pattern;
  final FragmentShader shader;
  final double devicePixelRatio;

  AutomationEditorPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.project,
    this.pattern,
    required this.shader,
    required this.devicePixelRatio,
  });

  ui.Image? imageCache;

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0.0; i < size.height; i += size.height / 5) {
      canvas.drawRect(
        Rect.fromLTWH(0, i, size.width, 1),
        Paint()..color = Theme.grid.major,
      );
    }

    paintTimeGrid(
      canvas: canvas,
      size: size,
      ticksPerQuarter: ticksPerQuarter,
      snap: AutoSnap(),
      baseTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    final points =
        pattern?.automationLanes[project.activeAutomationGeneratorID]?.points ??
            <AutomationPointModel>[];

    // This section draws each curve section one at a time to a texture, and
    // then draws that texture to the canvas.

    final recorder = ui.PictureRecorder();
    final recorderCanvas = ui.Canvas(recorder);
    recorderCanvas.clipRect(Rect.fromLTWH(
      0,
      0,
      size.width * devicePixelRatio,
      size.height * devicePixelRatio,
    ));

    AutomationPointModel? lastPoint;

    for (final point in points) {
      if (lastPoint == null) {
        lastPoint = point;
        continue;
      }

      final lastPointX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: lastPoint.offset,
      );
      final pointX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: point.offset,
      );

      final lastPointXFloor = lastPointX.floorToDouble();

      final xOffset = lastPointXFloor * devicePixelRatio;
      const yOffset = 0.0;

      shader.setFloatUniforms((setter) {
        lastPoint!;

        setter.setFloat((pointX - lastPointX) * devicePixelRatio);
        setter.setFloat(size.height * devicePixelRatio);

        setter.setFloat(xOffset);
        setter.setFloat(yOffset);

        setter.setFloat(lastPoint.offset);
        setter.setFloat(lastPoint.y);
        setter.setFloat(point.offset);
        setter.setFloat(point.y);
        setter.setFloat(point.tension);
      });

      final paint = Paint()..shader = shader;

      // TODO: We haven't yet dealt with the fact that the rectangle may be
      // wider than the thing it's supposed to draw. The rectangle will always
      // be on a pixel boundary, but the curve may not be. We should handle this
      // in the shader but we're not yet.
      recorderCanvas.drawRect(
        Rect.fromLTWH(
          xOffset,
          yOffset,
          (pointX.ceilToDouble() - lastPointXFloor) * devicePixelRatio,
          size.height * devicePixelRatio,
        ),
        paint,
      );

      lastPoint = point;
    }

    final curvesImage = recorder.endRecording().toImageSync(
          (size.width * devicePixelRatio).toInt(),
          (size.height * devicePixelRatio).toInt(),
        );

    canvas.drawImageRect(
      curvesImage,
      Rect.fromLTWH(
          0, 0, size.width * devicePixelRatio, size.height * devicePixelRatio),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // This section draws circles for each node, as well as circles for each
    // tension handle.

    lastPoint = null;

    for (final point in points) {
      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: point.offset,
      );
      final y = (1 - point.y) * size.height;

      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = const Color(0xFFab1593));

      // Tension handle
      if (lastPoint != null) {
        const normalizedX = 0.5;
        final normalizedY = evaluateSmooth(normalizedX, point.tension) *
                (point.y - lastPoint.y) +
            lastPoint.y;

        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: normalizedX * (point.offset - lastPoint.offset) +
              lastPoint.offset,
        );
        final y = (1 - normalizedY) * size.height;
        canvas.drawCircle(
            Offset(x, y), 2, Paint()..color = const Color(0xFF15ab93));
      }

      lastPoint = point;
    }
  }

  @override
  bool shouldRepaint(AutomationEditorPainter oldDelegate) =>
      timeViewStart != oldDelegate.timeViewStart ||
      timeViewEnd != oldDelegate.timeViewEnd ||
      ticksPerQuarter != oldDelegate.ticksPerQuarter ||
      project != oldDelegate.project ||
      pattern != oldDelegate.pattern ||
      super.shouldRepaint(oldDelegate);
}
