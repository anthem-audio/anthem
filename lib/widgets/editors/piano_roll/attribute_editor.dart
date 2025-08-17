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

import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/attribute_editor_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class PianoRollAttributeEditor extends StatefulWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final PianoRollViewModel viewModel;

  const PianoRollAttributeEditor({
    super.key,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.viewModel,
  });

  @override
  State<PianoRollAttributeEditor> createState() =>
      _PianoRollAttributeEditorState();
}

class _PianoRollAttributeEditorState extends State<PianoRollAttributeEditor> {
  late AttributeEditorController controller;

  @override
  void initState() {
    super.initState();
    controller = AttributeEditorController(viewModel: widget.viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AnthemTheme.panel.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: pianoControlWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, right: 4),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 20,
                        child: Observer(
                          builder: (context) {
                            return Dropdown(
                              allowNoSelection: false,
                              items: [
                                DropdownItem(
                                  id: ActiveNoteAttribute.velocity.name,
                                  name: 'Velocity',
                                ),
                                DropdownItem(
                                  id: ActiveNoteAttribute.pan.name,
                                  name: 'Pan',
                                ),
                              ],
                              selectedID: viewModel.activeNoteAttribute.name,
                              onChanged: (id) {
                                viewModel.activeNoteAttribute =
                                    ActiveNoteAttribute.values.firstWhere(
                                      (attribute) => attribute.name == id,
                                    );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: AnthemTheme.panel.border),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _AttributeRenderArea(
                          timeViewAnimationController:
                              widget.timeViewAnimationController,
                          timeViewStartAnimation: widget.timeViewStartAnimation,
                          timeViewEndAnimation: widget.timeViewEndAnimation,
                          controller: controller,
                        ),
                      ),
                      // If the attribute editor is open, then it should always
                      // show the scrollbar, since it's the item on the bottom
                      // of the view
                      PianoRollHorizontalScrollbar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 17),
      ],
    );
  }
}

class _AttributeRenderArea extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final AttributeEditorController controller;

  const _AttributeRenderArea({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        AttributeEditorPointerEvent createEditorPointerEvent(
          PointerEvent rawEvent,
        ) {
          return AttributeEditorPointerEvent(
            offset: pixelsToTime(
              timeViewStart: viewModel.timeView.start,
              timeViewEnd: viewModel.timeView.end,
              viewPixelWidth: constraints.maxWidth,
              pixelOffsetFromLeft: rawEvent.localPosition.dx,
            ),
            normalizedY:
                (1 - (rawEvent.localPosition.dy / constraints.maxHeight)).clamp(
                  0,
                  1,
                ),
            viewSize: constraints.biggest,
          );
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Listener(
            onPointerDown: (e) {
              controller.pointerDown(createEditorPointerEvent(e));
            },
            onPointerMove: (e) {
              controller.pointerMove(createEditorPointerEvent(e));
            },
            onPointerUp: (e) {
              controller.pointerUp(createEditorPointerEvent(e));
            },
            onPointerCancel: (e) {
              controller.pointerUp(createEditorPointerEvent(e));
            },
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
        );
      },
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
    final minorLinePaint = Paint()..color = AnthemTheme.grid.minor;

    const selectedNoteColor = HSLColor.fromAHSL(1, 166, 0.37, 0.37);
    const noteColor = HSLColor.fromAHSL(1, 166, 0.46, 0.31);
    const selectedNoteCircleColor = HSLColor.fromAHSL(1, 166, 0.41, 0.25);
    const noteCircleColor = HSLColor.fromAHSL(1, 166, 0.51, 0.23);

    final selectedNotePaint = Paint()..color = selectedNoteColor.toColor();
    final notePaint = Paint()..color = noteColor.toColor();
    final selectedNoteCirclePaint = Paint()
      ..color = selectedNoteCircleColor.toColor();
    final noteCirclePaint = Paint()..color = noteCircleColor.toColor();

    final activePattern =
        project.sequence.patterns[project.sequence.activePatternID];
    final selectedAttribute = viewModel.activeNoteAttribute;

    int bottom;
    int baseline;
    int top;

    switch (selectedAttribute) {
      case ActiveNoteAttribute.velocity:
        bottom = ActiveNoteAttribute.velocity.bottom;
        baseline = ActiveNoteAttribute.velocity.baseline;
        top = ActiveNoteAttribute.velocity.top;
        break;
      case ActiveNoteAttribute.pan:
        bottom = ActiveNoteAttribute.pan.bottom;
        baseline = ActiveNoteAttribute.pan.baseline;
        top = ActiveNoteAttribute.pan.top;
        break;
    }

    paintTimeGrid(
      canvas: canvas,
      size: size,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      snap: AutoSnap(),
      baseTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: activePattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    // No vertical zoom for now

    const verticalDivisionCount = 4;
    for (var i = 1; i < verticalDivisionCount; i++) {
      final rect = Rect.fromLTWH(
        0,
        size.height * i / verticalDivisionCount,
        size.width,
        1,
      );
      canvas.drawRect(rect, minorLinePaint);
    }

    final notes = activePattern?.notes[project.activeInstrumentID];

    if (notes == null) return;

    for (final note in notes) {
      double attribute;

      switch (selectedAttribute) {
        case ActiveNoteAttribute.velocity:
          attribute = note.velocity;
          break;
        case ActiveNoteAttribute.pan:
          attribute = note.pan;
          break;
      }

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

      double valueToPixels(num value) =>
          ((1 - ((value - bottom) / (top - bottom))) * size.height)
              .round()
              .toDouble();

      final barTop = valueToPixels(attribute);
      final barBottom = valueToPixels(baseline);

      canvas.drawRect(
        Rect.fromPoints(Offset(startX, barTop), Offset(startX + 3, barBottom)),
        paint,
      );

      canvas.drawRect(Rect.fromLTWH(startX, barTop, endX - startX, 1), paint);

      final circlePos = Offset(startX + 1.5, barTop + 0.5);
      canvas.drawCircle(circlePos, 3.5, paint);
      canvas.drawCircle(circlePos, 2.5, circleCenterPaint);
    }
  }
}
