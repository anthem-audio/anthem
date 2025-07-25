/*
  Copyright (C) 2023 - 2025 Joshua Wade

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
import 'dart:ui' as ui;

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/automation_editor/automation_point_animation_tracker.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/smooth.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:provider/provider.dart';

class AutomationEditorContentRenderer extends StatefulObserverWidget {
  final double timeViewStart;
  final double timeViewEnd;

  const AutomationEditorContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  @override
  State<AutomationEditorContentRenderer> createState() =>
      _AutomationEditorContentRendererState();
}

class _AutomationEditorContentRendererState
    extends State<AutomationEditorContentRenderer> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final pattern = project.sequence.patterns[project.sequence.activePatternID];
    final viewModel = Provider.of<AutomationEditorViewModel>(context);

    // Rebuild when these two change
    viewModel.hoveredPointAnnotation;
    viewModel.pressedPointAnnotation;

    // Ensure animation continues if it's still going
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.pointAnimationTracker.isActive) {
        setState(() {});
      }
    });

    return ShaderBuilder(
      assetKey: 'assets/shaders/automation_curve.frag',
      (context, shader, child) => CustomPaintObserver(
        painterBuilder: () => AutomationEditorPainter(
          timeViewStart: widget.timeViewStart,
          timeViewEnd: widget.timeViewEnd,
          ticksPerQuarter: project.sequence.ticksPerQuarter,
          project: project,
          pattern: pattern,
          shader: shader,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          visiblePoints: viewModel.visiblePoints,
          viewModel: viewModel,
        ),
        isComplex: true,
      ),
    );
  }
}

const pointAnnotationMargin = 8;

class AutomationEditorPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final ProjectModel project;
  final PatternModel? pattern;
  final FragmentShader shader;
  final double devicePixelRatio;
  final CanvasAnnotationSet<PointAnnotation> visiblePoints;
  final AutomationEditorViewModel viewModel;

  AutomationEditorPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.project,
    this.pattern,
    required this.shader,
    required this.devicePixelRatio,
    required this.visiblePoints,
    required this.viewModel,
  });

  ui.Image? imageCache;

  @override
  void observablePaint(Canvas canvas, Size size) {
    visiblePoints.clear();
    viewModel.pointAnimationTracker.update();

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final horizontalLineStep = size.height / 5;
    for (var i = horizontalLineStep; i < size.height; i += horizontalLineStep) {
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
      baseTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    final points =
        pattern?.automationLanes[project.activeAutomationGeneratorID]?.points;

    if (points != null) {
      points.observeAllChanges();

      blockObservation(
        modelItems: [points],
        block: () => _paintAutomationEditor(canvas, size, points),
      );
    }
  }

  void _paintAutomationEditor(
    Canvas canvas,
    Size size,
    AnthemObservableList<AutomationPointModel> points,
  ) {
    const strokeWidth = 2.0;

    // This section draws each curve section one at a time.

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
        time: lastPoint.offset.toDouble(),
      );
      final pointX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: point.offset.toDouble(),
      );

      if ((lastPointX < 0 && pointX < 0) ||
          (lastPointX > size.width && pointX > size.width)) {
        lastPoint = point;
        continue;
      }

      final xOffset = (lastPointX - strokeWidth * 0.5);
      const yOffset = 0.0;

      drawCurve(
        canvas,
        shader,
        drawArea: Rectangle(xOffset, yOffset, pointX - lastPointX, size.height),
        devicePixelRatio: devicePixelRatio,
        firstPointValue: lastPoint.value,
        secondPointValue: point.value,
        tension: point.tension,
        strokeWidth: strokeWidth,
        color: Theme.primary.main,
        gradientOpacityTop: 0.2,
        gradientOpacityBottom: 0.03,
      );

      lastPoint = point;
    }

    // This section draws circles for each node, as well as circles for each
    // tension handle.

    lastPoint = null;
    var i = 0;

    for (final point in points) {
      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: point.offset.toDouble(),
      );
      final y = (1 - point.value) * size.height;
      final center = Offset(x, y);
      const radius = 3.5;
      final hoveredPoint = viewModel.hoveredPointAnnotation;
      final pressedPoint = viewModel.pressedPointAnnotation;
      final radiusMultiplier = getRadiusMultiplier(
        tracker: viewModel.pointAnimationTracker,
        pointId: point.id,
        hoveredPoint: hoveredPoint,
        pressedPoint: pressedPoint,
        handleKind: HandleKind.point,
      );

      canvas.drawCircle(
        center,
        radius * radiusMultiplier,
        Paint()..color = Theme.grid.backgroundDark,
      );
      canvas.drawCircle(
        center,
        radius * radiusMultiplier,
        Paint()
          ..color = Theme.primary.main
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      visiblePoints.add(
        rect: Rect.fromCenter(
          center: center,
          width: radius * 2 + pointAnnotationMargin,
          height: radius * 2 + pointAnnotationMargin,
        ),
        metadata: (
          kind: HandleKind.point,
          center: center,
          pointIndex: i,
          pointId: point.id,
        ),
      );

      // Tension handle
      if (lastPoint != null) {
        const normalizedX = 0.5;
        final normalizedY =
            evaluateSmooth(normalizedX, point.tension) *
                (point.value - lastPoint.value) +
            lastPoint.value;

        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time:
              normalizedX * (point.offset - lastPoint.offset) +
              lastPoint.offset,
        );
        final y = (1 - normalizedY) * size.height;
        final center = Offset(x, y);
        const radius = 2.5;
        final radiusMultiplier = getRadiusMultiplier(
          tracker: viewModel.pointAnimationTracker,
          pointId: point.id,
          hoveredPoint: hoveredPoint,
          pressedPoint: pressedPoint,
          handleKind: HandleKind.tensionHandle,
        );

        canvas.drawCircle(
          center,
          radius * radiusMultiplier,
          Paint()..color = Theme.grid.backgroundDark,
        );
        canvas.drawCircle(
          center,
          radius * radiusMultiplier,
          Paint()
            ..color = Theme.primary.main
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth,
        );
        visiblePoints.add(
          rect: Rect.fromCenter(
            center: center,
            width: radius * 2 + pointAnnotationMargin,
            height: radius * 2 + pointAnnotationMargin,
          ),
          metadata: (
            kind: HandleKind.tensionHandle,
            center: center,
            pointIndex: i,
            pointId: point.id,
          ),
        );
      }

      lastPoint = point;
      i++;
    }
  }

  @override
  bool shouldRepaint(AutomationEditorPainter oldDelegate) =>
      viewModel.pointAnimationTracker.isActive ||
      timeViewStart != oldDelegate.timeViewStart ||
      timeViewEnd != oldDelegate.timeViewEnd ||
      ticksPerQuarter != oldDelegate.ticksPerQuarter ||
      project != oldDelegate.project ||
      pattern != oldDelegate.pattern ||
      shader != oldDelegate.shader ||
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      visiblePoints != oldDelegate.visiblePoints ||
      viewModel != oldDelegate.viewModel ||
      super.shouldRepaint(oldDelegate);
}

double getRadiusMultiplier({
  required AutomationPointAnimationTracker tracker,
  required Id pointId,
  required PointAnnotation? hoveredPoint,
  required PointAnnotation? pressedPoint,
  required HandleKind handleKind,
}) {
  final animationValue = tracker.values[(id: pointId, handleKind: handleKind)];

  if (animationValue != null) {
    return animationValue.current;
  }

  if (pressedPoint?.pointId == pointId && pressedPoint?.kind == handleKind) {
    return automationPointPressedSizeMultiplier;
  }

  if (hoveredPoint?.pointId == pointId && hoveredPoint?.kind == handleKind) {
    return automationPointHoveredSizeMultiplier;
  }

  return 1;
}
