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

import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class PianoRollAttributeEditor extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;

  const PianoRollAttributeEditor({
    super.key,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.panel.border),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: pianoControlWidth + 1),
                Expanded(
                  child: AnimatedBuilder(
                    animation: timeViewAnimationController,
                    builder: (context, child) {
                      return ClipRect(
                        child: CustomPaintObserver(
                          painterBuilder: () => PianoRollAttributePainter(
                            viewModel: viewModel,
                            project: project,
                            timeViewStart: timeViewStartAnimation.value,
                            timeViewEnd: timeViewEndAnimation.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        const SizedBox(
          width: 17,
        ),
      ],
    );
  }
}

class PianoRollAttributePainter extends CustomPainterObserver {
  PianoRollViewModel viewModel;
  ProjectModel project;
  double timeViewStart;
  double timeViewEnd;

  PianoRollAttributePainter({
    required this.viewModel,
    required this.project,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    final minorLinePaint = Paint()..color = Theme.grid.minor;

    const selectedNoteColor = HSLColor.fromAHSL(1, 166, 0.37, 0.37);
    const noteColor = HSLColor.fromAHSL(1, 166, 0.46, 0.31);
    const selectedNoteCircleColor = HSLColor.fromAHSL(1, 166, 0.41, 0.25);
    const noteCircleColor = HSLColor.fromAHSL(1, 166, 0.51, 0.23);

    final selectedNotePaint = Paint()..color = selectedNoteColor.toColor();
    final notePaint = Paint()..color = noteColor.toColor();
    final selectedNoteCirclePaint = Paint()
      ..color = selectedNoteCircleColor.toColor();
    final noteCirclePaint = Paint()..color = noteCircleColor.toColor();

    final activePattern = project.song.patterns[project.song.activePatternID];

    paintTimeGrid(
      canvas: canvas,
      size: size,
      ticksPerQuarter: project.song.ticksPerQuarter,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      baseTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: activePattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    // No vertical zoom for now

    const verticalDivisionCount = 4;
    for (var i = 1; i < verticalDivisionCount; i++) {
      final rect = Rect.fromLTWH(
          0, size.height * i / verticalDivisionCount, size.width, 1);
      canvas.drawRect(rect, minorLinePaint);
    }

    final notes = activePattern?.notes[project.activeGeneratorID];

    if (notes == null) return;

    for (final note in notes) {
      final startX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: note.offset.toDouble(),
      );

      final endX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: note.offset.toDouble() + note.length.toDouble(),
      );

      if (endX < 0 || startX > size.width) continue;

      final paint = viewModel.selectedNotes.contains(note.id)
          ? selectedNotePaint
          : notePaint;
      final circleCenterPaint = viewModel.selectedNotes.contains(note.id)
          ? selectedNoteCirclePaint
          : noteCirclePaint;

      final barTop =
          ((1 - (note.velocity / 127)) * size.height).round().toDouble();

      canvas.drawRect(
        Rect.fromPoints(
          Offset(startX, barTop),
          Offset(startX + 3, size.height),
        ),
        paint,
      );

      canvas.drawRect(
        Rect.fromLTWH(startX, barTop, endX - startX, 1),
        paint,
      );

      final circlePos = Offset(startX + 1.5, barTop + 0.5);
      canvas.drawCircle(circlePos, 3.5, paint);
      canvas.drawCircle(circlePos, 2.5, circleCenterPaint);
    }
  }
}
