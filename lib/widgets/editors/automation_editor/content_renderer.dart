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

  @override
  void observablePaint(Canvas canvas, Size size) {
    final recorder = PictureRecorder();
    final recorderCanvas = Canvas(recorder);

    recorderCanvas.clipRect(Rect.fromLTWH(
      0,
      0,
      size.width * devicePixelRatio,
      size.height * devicePixelRatio,
    ));

    for (var i = 0.0;
        i < size.height * devicePixelRatio;
        i += size.height * devicePixelRatio / 5) {
      recorderCanvas.drawRect(
        Rect.fromLTWH(0, i, size.width * devicePixelRatio, devicePixelRatio),
        Paint()..color = Theme.grid.major,
      );
    }

    paintTimeGrid(
      canvas: recorderCanvas,
      size: size,
      ticksPerQuarter: ticksPerQuarter,
      snap: AutoSnap(),
      baseTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      devicePixelRatio: devicePixelRatio,
    );

    final backgroundImage = recorder.endRecording().toImageSync(
          (size.width * devicePixelRatio).toInt(),
          (size.height * devicePixelRatio).toInt(),
        );

    shader.setImageSampler(0, backgroundImage);

    shader.setFloatUniforms((setter) {
      setter.setFloat(size.width);
      setter.setFloat(size.height);
      setter.setFloat(timeViewStart);
      setter.setFloat(timeViewEnd);
    });

    final paint = Paint()..shader = shader;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    AutomationPointModel? lastPoint;
    for (final point in pattern
            ?.automationLanes[project.activeAutomationGeneratorID]?.points ??
        <AutomationPointModel>[]) {
      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: point.offset,
      );
      final y = (1 - point.y) * size.height;

      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = const Color(0xFFab1593));

      if (lastPoint != null) {
        final resolution = (timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: point.offset,
            ) -
            timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: lastPoint.offset,
            ));

        for (int i = 0; i < resolution; i++) {
          final normalizedX = i / resolution;
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
