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

import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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

    return CustomPaintObserver(
      painterBuilder: () => AutomationEditorPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        ticksPerQuarter: project.song.ticksPerQuarter,
        project: project,
        pattern: pattern,
      ),
      isComplex: true,
    );
  }
}

class AutomationEditorPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final ProjectModel project;
  final PatternModel? pattern;

  AutomationEditorPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.project,
    this.pattern,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

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

    for (var i = 0.0; i < size.height; i += size.height / 5) {
      canvas.drawRect(
        Rect.fromLTWH(0, i, size.width, 1),
        Paint()..color = Theme.grid.major,
      );
    }
  }

  @override
  bool shouldRepaint(AutomationEditorPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate);
}
