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
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class PianoRollContentRenderer extends StatelessWidget {
  final double timeViewStart;
  final double timeViewEnd;
  final double keyValueAtTop;

  const PianoRollContentRenderer({
    Key? key,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return CustomPaintObserver(
      painterBuilder: () => PianoRollPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        keyValueAtTop: keyValueAtTop,
        project: project,
        viewModel: viewModel,
      ),
    );
  }
}

class PianoRollPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final double keyValueAtTop;
  final PianoRollViewModel viewModel;
  final ProjectModel project;

  PianoRollPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
    required this.viewModel,
    required this.project,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    final pattern = project.song.patterns[project.song.activePatternID];
    if (pattern == null) return;

    final notes = pattern.notes[project.activeGeneratorID];
    if (notes == null) return;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final note in notes) {
      final isPressed = viewModel.pressedNote == note.id;
      final isSelected = viewModel.selectedNotes.contains(note.id);
      // final isHovered = false;

      var saturation = isPressed
          ? 0.6
          : isSelected
              ? 0.37
              : 0.46;

      var lightness = isPressed
          ? 0.22
          : isSelected
              ? 0.37
              : 0.31;

      // if (isHovered && !isPressed) {
      //   saturation -= 0.06;
      //   lightness += 0.04;
      // }

      final color = HSLColor.fromAHSL(1, 166, saturation, lightness).toColor();
      final borderColor = isSelected
          ? const HSLColor.fromAHSL(1, 166, 0.35, 0.45).toColor()
          : const Color(0x00000000);
      // final textColor = HSLColor.fromAHSL(
      //   1,
      //   166,
      //   (saturation * 0.6).clamp(0, 1),
      //   (lightness * 2).clamp(0, 1),
      // ).toColor();

      final x = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: note.offset.toDouble(),
          ) +
          1;
      final y = keyValueToPixels(
            keyValue: note.key.toDouble() + 1,
            keyValueAtTop: keyValueAtTop,
            keyHeight: viewModel.keyHeight,
          ) +
          1;
      final width = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: (note.offset + note.length).toDouble(),
          ) -
          x;
      final height = viewModel.keyHeight - 1;

      if (x > size.width || x + width < 0) continue;
      if (y > size.height || y + height < 0) continue;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        const Radius.circular(1),
      );
      // Borders are drawn along the edge of the shape, with half the border
      // inside and half outside. We want all of it to be inside, and this
      // rectangle accounts for this issue.
      final borderRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1),
        const Radius.circular(1),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = color,
      );
      canvas.drawRRect(
        borderRect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(PianoRollPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate);
}
