/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:anthem/color_shifter.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
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
  final bool shouldGreyOut;

  const PianoRollContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
    required this.shouldGreyOut,
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
        shouldGreyOut: shouldGreyOut,
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
  final bool shouldGreyOut;

  PianoRollPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.keyValueAtTop,
    required this.viewModel,
    required this.project,
    required this.devicePixelRatio,
    required this.shouldGreyOut,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    viewModel.visibleNotes.clear();
    viewModel.visibleResizeAreas.clear();

    final pattern = project.sequence.patterns[project.sequence.activePatternID];
    if (shouldGreyOut || pattern == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0x88404040),
      );
      return;
    }

    final notes = pattern.notes;
    final noteOverrides = pattern.noteOverrides;
    final previewNotes = pattern.previewNotes;

    notes.observeAllChanges();
    noteOverrides.observeAllChanges();
    previewNotes.observeAllChanges();

    blockObservation(
      modelItems: [notes, noteOverrides, previewNotes],
      block: () {
        _drawNotes(canvas, size, pattern);
      },
    );
  }

  void _drawNotes(Canvas canvas, Size size, PatternModel pattern) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final colorShifter = AnthemColorShifter(AnthemTheme.primary.main);
    final resolvedNotes = viewModel.resolveRenderedNotes(pattern);

    for (final note in resolvedNotes) {
      final noteRef = viewModel.renderedRefFor(note);
      final keyHeight = viewModel.keyHeight;
      final key = note.key;
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
        time: (note.offset + note.length).toDouble(),
      );
      final x = startX + 1;
      final y =
          keyValueToPixels(
            keyValue: key.toDouble() + 1,
            keyValueAtTop: keyValueAtTop,
            keyHeight: keyHeight,
          ) +
          1;
      final width = (endX - x).clamp(0.0, double.infinity);
      final height = keyHeight - 1;

      if (x > size.width || endX < 0) continue;
      if (y > size.height || y + height < 0) continue;
      if (width <= 0 || height <= 0) continue;

      final isPressed = viewModel.isNotePressed(note);
      final isSelected = viewModel.isNoteSelected(note);
      final isHovered = viewModel.isNoteHovered(note);

      var color = colorShifter.noteBase;
      if (isHovered && !isPressed) {
        color = colorShifter.noteHovered;
      } else if (isPressed) {
        color = colorShifter.notePressed;
      }

      var borderColor = colorShifter.noteBase;
      if (isSelected) {
        borderColor = colorShifter.noteSelectedBorder;
        color = colorShifter.noteSelected;
        if (isPressed) {
          color = colorShifter.notePressed;
        } else if (isHovered) {
          color = colorShifter.noteBase; // Looks better with the select border
        }
      }

      final noteRect = Rect.fromLTWH(x, y, width, height);
      final rect = RRect.fromRectAndRadius(noteRect, const Radius.circular(1));
      // Borders are drawn along the edge of the shape, with half the border
      // inside and half outside. We want all of it to be inside, and this
      // rectangle accounts for this issue.
      canvas.drawRRect(rect, Paint()..color = color);

      if (isSelected && width > 1 && height > 1) {
        final borderRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1),
          const Radius.circular(1),
        );
        canvas.drawRRect(
          borderRect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      if (keyHeight > 25 && width > 2 && height > 2) {
        final cachedLabel = noteLabelImageCache.get(key);
        if (cachedLabel == null) continue;

        canvas.save();
        final clipRect = Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2);
        canvas.clipRect(clipRect);

        final textColor = white;

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
            ),
          ],
          [textColor],
          BlendMode.dstIn,
          null,
          Paint(),
        );

        final transparentColor = color.withAlpha(0);

        // Fade out gradient
        final textFadeOutStop = (1 - (10 / width)).clamp(0.0, 1.0);
        final textFadeOutGradient = ui.Gradient.linear(
          Offset(x, textY),
          Offset(x + width - 3, textY),
          [transparentColor, transparentColor, color],
          [0, textFadeOutStop, 1],
        );

        final textFadeOutPaint = Paint()..shader = textFadeOutGradient;

        canvas.drawRect(clipRect, textFadeOutPaint);

        canvas.restore();
      }

      viewModel.visibleNotes.add(rect: noteRect, metadata: noteRef);

      // Notice this is fromLTRB. We generally use fromLTWH elsewhere.
      final endResizeHandleRect = Rect.fromLTRB(
        x +
            (width - (_noteResizeHandleWidth - _noteResizeHandleOvershoot))
                // Ensures there's a bit of the note still showing
                .clamp(_minimumClickableNoteArea.toDouble(), double.infinity)
                .clamp(0, width),
        y,
        x + width + _noteResizeHandleOvershoot,
        y + keyHeight - 1,
      );

      viewModel.visibleResizeAreas.add(
        rect: endResizeHandleRect,
        metadata: noteRef,
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
      shouldGreyOut != oldDelegate.shouldGreyOut ||
      super.shouldRepaint(oldDelegate);
}
