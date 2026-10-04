/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_renderer.dart';
import 'package:flutter/widgets.dart';

/// Isolates clip-bound sampling from the rest of the arranger and audio engine.
class AutomationCurveBoundsWidgetTestScreen extends StatefulWidget {
  const AutomationCurveBoundsWidgetTestScreen({super.key});

  @override
  State<AutomationCurveBoundsWidgetTestScreen> createState() =>
      _AutomationCurveBoundsWidgetTestScreenState();
}

class _AutomationCurveBoundsWidgetTestScreenState
    extends State<AutomationCurveBoundsWidgetTestScreen> {
  late final ProjectModel project;
  late final List<PatternModel> patterns;
  late final List<PatternModel> flatPatterns;

  @override
  void initState() {
    super.initState();
    project = ProjectModel.create();
    patterns = [
      for (final tension in [-0.95, 0.95])
        PatternModel(idAllocator: project.idAllocator, name: 'Track automation')
          ..automation.points.addAll([
            AutomationPointModel(
              idAllocator: project.idAllocator,
              offset: 0,
              value: 1,
            ),
            AutomationPointModel(
              idAllocator: project.idAllocator,
              offset: 70,
              value: 0,
              tension: tension,
            ),
          ]),
    ];
    flatPatterns = [
      for (final value in [0.0, 1.0])
        PatternModel(idAllocator: project.idAllocator, name: 'Track automation')
          ..automation.points.addAll([
            AutomationPointModel(
              idAllocator: project.idAllocator,
              offset: 0,
              value: value,
            ),
            AutomationPointModel(
              idAllocator: project.idAllocator,
              offset: 70,
              value: value,
            ),
          ]),
    ];
    for (final pattern in [...patterns, ...flatPatterns]) {
      project.sequence.patterns[pattern.id] = pattern;
    }
  }

  @override
  void dispose() {
    project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CustomPaint(
        size: const Size(360, 365),
        painter: _AutomationCurveBoundsPainter(
          project: project,
          patterns: patterns,
          flatPatterns: flatPatterns,
        ),
      ),
    );
  }
}

class _AutomationCurveBoundsPainter extends CustomPainter {
  final ProjectModel project;
  final List<PatternModel> patterns;
  final List<PatternModel> flatPatterns;

  _AutomationCurveBoundsPainter({
    required this.project,
    required this.patterns,
    required this.flatPatterns,
  });

  ClipRenderInfo _clip(PatternModel pattern, int x, double y) {
    return ClipRenderInfo(
      pattern: pattern,
      color: AnthemColor(hue: 0, palette: .grayscale),
      clipId: pattern.id,
      trackId: project.trackOrder.first,
      hasTimingOverride: false,
      clipOffset: x,
      clipTimeViewStart: 0,
      clipTimeViewEnd: 70,
      x: x.toDouble(),
      y: y,
      width: 71,
      height: 86,
      selected: false,
      hovered: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _label(
      canvas,
      'One-pixel scaling on the left only (batched)',
      const Offset(0, 0),
    );
    _label(
      canvas,
      'Clip and curve segment both span 70 px',
      const Offset(0, 20),
    );
    _label(
      canvas,
      'Horizontal curves keep their right endpoint',
      const Offset(0, 186),
    );

    paintClipList(
      project: project,
      canvas: canvas,
      canvasSize: size,
      automationHandleAnnotations: AutomationHandleAnnotationSet(),
      hoveredAutomationHandle: null,
      clipList: [
        for (var i = 0; i < patterns.length; i++)
          _clip(patterns[i], 40 + i * 180, 48),
        for (var i = 0; i < flatPatterns.length; i++)
          _clip(flatPatterns[i], 40 + i * 180, 222),
      ],
      devicePixelRatio: 1,
      timeViewStart: 0,
      timeViewEnd: size.width,
    );

    for (var i = 0; i < patterns.length; i++) {
      final x = 40.0 + i * 180;
      final tension = patterns[i].automation.points.last.tension;
      _label(canvas, 'Tension $tension', Offset(x - 8, 146));
      final value = flatPatterns[i].automation.points.first.value;
      _label(canvas, 'Value $value', Offset(x - 8, 320));
    }
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 360);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_AutomationCurveBoundsPainter oldDelegate) => false;
}
