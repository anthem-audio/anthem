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

import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/note_label_image_cache.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

/// Size of the resize handles, in pixels.
const _noteResizeHandleWidth = 12.0;

/// How far over the note the resize handle extends, in pixels.
const _noteResizeHandleOvershoot = 2.0;

/// There will be at least this much clickable area on a note. Resize handles
/// will shrink to make room for this if necessary.
const _minimumClickableNoteArea = 30;

class PianoRollContentRenderer extends StatelessWidget {
  final double timeViewStart;
  final double timeViewEnd;
  final double keyValueAtTop;

  const PianoRollContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
  });

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
        devicePixelRatio: View.of(context).devicePixelRatio,
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
  final double devicePixelRatio;

  PianoRollPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
    required this.viewModel,
    required this.project,
    required this.devicePixelRatio,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    viewModel.visibleNotes.clear();
    viewModel.visibleResizeAreas.clear();

    final pattern = project.sequence.patterns[project.sequence.activePatternID];
    if (pattern == null) return;

    final notes = pattern.notes[project.activeInstrumentID];
    if (notes == null) return;

    notes.observeAllChanges();

    blockObservation(
      modelItems: [notes],
      block: () {
        _drawNotes(canvas, size, notes);
      },
    );
  }

  void _drawNotes(
      Canvas canvas, Size size, AnthemObservableList<NoteModel> notes) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final note in notes) {
      final keyHeight = viewModel.keyHeight;
      final key = note.key;
      final x = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: note.offset.toDouble(),
          ) +
          1;
      final y = keyValueToPixels(
            keyValue: key.toDouble() + 1,
            keyValueAtTop: keyValueAtTop,
            keyHeight: keyHeight,
          ) +
          1;
      final width = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: (note.offset + note.length).toDouble(),
          ) -
          x;
      final height = keyHeight - 1;

      if (x > size.width || x + width < 0) continue;
      if (y > size.height || y + height < 0) continue;

      final isPressed = viewModel.pressedNote == note.id;
      final isSelected = viewModel.selectedNotes.contains(note.id);
      final isHovered = viewModel.hoveredNote == note.id;

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

      if (isHovered && !isPressed) {
        saturation -= 0.06;
        lightness += 0.04;
      }

      final color = HSLColor.fromAHSL(1, 166, saturation, lightness).toColor();
      final borderColor = const HSLColor.fromAHSL(1, 166, 0.35, 0.45).toColor();

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

      if (isSelected) {
        canvas.drawRRect(
          borderRect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      if (keyHeight > 25) {
        canvas.save();
        final clipRect = Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2);
        canvas.clipRect(clipRect);

        final cachedLabel = noteLabelImageCache.get(key);
        if (cachedLabel == null) return;

        final textColor = HSLColor.fromAHSL(
          1,
          166,
          (saturation * 0.6).clamp(0, 1),
          (lightness * 2).clamp(0, 1),
        ).toColor();

        final textX = x + 5;
        final textY = y + (keyHeight - noteLabelHeight) * 0.5 - 1;

        // canvas.drawImageRect(cachedLabel, Rect.fromLTWH(x, y, cachedLabel.width.toDouble(), cachedLabel.height.toDouble()), Paint());
        canvas.drawAtlas(
          cachedLabel,
          [
            RSTransform.fromComponents(
              rotation: 0,
              scale: 1 / devicePixelRatio,
              anchorX: 0,
              anchorY: 0,
              translateX: textX,
              translateY: textY,
            ),
          ],
          [
            Rect.fromLTWH(
              0,
              0,
              noteLabelWidth * devicePixelRatio,
              noteLabelHeight * devicePixelRatio,
            )
          ],
          [textColor],
          BlendMode.dstIn,
          null,
          Paint(),
        );

        final transparentColor = color.withAlpha(0);

        // Fade out gradient
        final textFadeOutGradient = ui.Gradient.linear(
          Offset(x, textY),
          Offset(x + width - 3, textY),
          [transparentColor, transparentColor, color],
          [0, 1 - (10 / width), 1],
        );

        final textFadeOutPaint = Paint()..shader = textFadeOutGradient;

        canvas.drawRect(clipRect, textFadeOutPaint);

        canvas.restore();
      }

      viewModel.visibleNotes.add(
        rect: rect.outerRect,
        metadata: (id: note.id),
      );

      // Notice this is fromLTRB. We generally use fromLTWH elsewhere.
      final endResizeHandleRect = Rect.fromLTRB(
        x +
            (width - (_noteResizeHandleWidth - _noteResizeHandleOvershoot))
                // Ensures there's a bit of the note still showing
                .clamp(_minimumClickableNoteArea, double.infinity)
                .clamp(0, width),
        y,
        x + width + _noteResizeHandleOvershoot,
        y + keyHeight - 1,
      );

      viewModel.visibleResizeAreas.add(
        rect: endResizeHandleRect,
        metadata: (id: note.id),
      );
    }
  }

  @override
  bool shouldRepaint(PianoRollPainter oldDelegate) =>
      timeViewStart != oldDelegate.timeViewStart ||
      timeViewEnd != oldDelegate.timeViewEnd ||
      keyValueAtTop != oldDelegate.keyValueAtTop ||
      viewModel != oldDelegate.viewModel ||
      project != oldDelegate.project ||
      super.shouldRepaint(oldDelegate);
}
