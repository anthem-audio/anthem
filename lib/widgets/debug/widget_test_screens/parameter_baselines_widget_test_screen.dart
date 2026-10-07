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

import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/editors/arranger/rendering/automation_curve_renderer.dart';
import 'package:flutter/widgets.dart';

/// Compares knob arcs and automation fills at minimum, center, and arbitrary
/// baselines. Every row uses the same curve and control values.
class ParameterBaselinesWidgetTestScreen extends StatefulWidget {
  const ParameterBaselinesWidgetTestScreen({super.key});

  @override
  State<ParameterBaselinesWidgetTestScreen> createState() =>
      _ParameterBaselinesWidgetTestScreenState();
}

class _ParameterBaselinesWidgetTestScreenState
    extends State<ParameterBaselinesWidgetTestScreen> {
  late final ProjectModel project;
  late final PatternModel pattern;

  @override
  void initState() {
    super.initState();
    project = ProjectModel.create();
    pattern = PatternModel(
      idAllocator: project.idAllocator,
      name: 'Baseline example',
    );
    project.sequence.patterns[pattern.id] = pattern;
    pattern.automation.points.addAll([
      for (final (offset, value) in [(0, 0.1), (100, 0.9), (200, 0.25)])
        AutomationPointModel(
          idAllocator: project.idAllocator,
          offset: offset,
          value: value,
        ),
    ]);
  }

  @override
  void dispose() {
    project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: [
        for (final (label, baseline) in [
          ('Minimum baseline (gain / unknown plugin)', 0.0),
          ('Center baseline (pan)', 0.5),
          ('Off-center baseline', 0.25),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFFDDDDDD))),
              Row(
                spacing: 20,
                children: [
                  for (final value in [0.25, 0.5, 0.75])
                    Column(
                      spacing: 6,
                      children: [
                        Knob(
                          width: 38,
                          height: 38,
                          value: value,
                          normalizedVisualBaseline: baseline,
                        ),
                        Text(
                          '$value',
                          style: const TextStyle(
                            color: Color(0xFFDDDDDD),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  CustomPaint(
                    size: const Size(260, 70),
                    painter: _BaselineCurvePainter(
                      pattern: pattern,
                      baseline: baseline,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _BaselineCurvePainter extends CustomPainter {
  final PatternModel pattern;
  final double baseline;

  _BaselineCurvePainter({required this.pattern, required this.baseline});

  @override
  void paint(Canvas canvas, Size size) {
    final lines = LineBuffer();
    final joins = CoordinateBuffer();
    final fill = CoordinateBuffer();
    const top = 4.0;
    final bottom = size.height - 4;
    final baseY = top + (bottom - top) * (1 - baseline);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF292929),
    );
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()..color = const Color(0xFF666666),
    );
    renderAutomationCurve(
      canvas: canvas,
      canvasSize: size,
      xDrawPositionTime: (0, 200),
      yDrawPositionPixels: (top, bottom),
      points: pattern.automation.points,
      strokeWidth: 2,
      timeViewStart: 0,
      timeViewEnd: 200,
      normalizedVisualBaseline: baseline,
      lineBuffer: lines,
      lineJoinBuffer: joins,
      triCoordBuffer: fill,
    );
    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, fill.buffer),
      BlendMode.srcOver,
      Paint()..color = const Color(0x3028D1AA),
    );
    canvas.drawRawPoints(
      PointMode.lines,
      lines.buffer,
      getLinePaint(chosenColor: const Color(0xFF28D1AA), strokeWidth: 2),
    );
    canvas.drawRawPoints(
      PointMode.points,
      joins.buffer,
      getLineJoinPaint(chosenColor: const Color(0xFF28D1AA), strokeWidth: 2),
    );
  }

  @override
  bool shouldRepaint(_BaselineCurvePainter oldDelegate) =>
      pattern != oldDelegate.pattern || baseline != oldDelegate.baseline;
}
