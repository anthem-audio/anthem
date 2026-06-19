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
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/stem_editor_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_left_edge_border.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/time_range_animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class PianoRollStemEditor extends StatefulWidget {
  final TimeRangeAnimation timeRangeAnimation;
  final PianoRollViewModel viewModel;

  const PianoRollStemEditor({
    super.key,
    required this.timeRangeAnimation,
    required this.viewModel,
  });

  @override
  State<PianoRollStemEditor> createState() => _PianoRollStemEditorState();
}

class _PianoRollStemEditorState extends State<PianoRollStemEditor> {
  late PianoRollStemEditorController controller;
  bool _controllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controllerInitialized) {
      return;
    }

    controller = PianoRollStemEditorController(
      project: Provider.of<ProjectModel>(context, listen: false),
      viewModel: widget.viewModel,
    );
    _controllerInitialized = true;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AnthemTheme.panel.border),
                right: BorderSide(color: AnthemTheme.panel.border),
              ),
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
                                  id: PianoRollStem.velocity.name,
                                  name: 'Velocity',
                                ),
                                DropdownItem(
                                  id: PianoRollStem.pan.name,
                                  name: 'Pan',
                                ),
                              ],
                              selectedID: viewModel.activeStem.name,
                              onChanged: (id) {
                                viewModel.activeStem = PianoRollStem.values
                                    .firstWhere((stem) => stem.name == id);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _StemRenderArea(
                          timeRangeAnimation: widget.timeRangeAnimation,
                          controller: controller,
                        ),
                      ),
                      // If the stem editor is open, then it should always
                      // show the scrollbar, since it's the item on the bottom
                      // of the view
                      Container(height: 1, color: AnthemTheme.panel.border),
                      PianoRollHorizontalScrollbar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 16,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(width: 1, color: AnthemTheme.panel.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _StemRenderArea extends StatelessWidget {
  final TimeRangeAnimation timeRangeAnimation;
  final PianoRollStemEditorController controller;

  const _StemRenderArea({
    required this.timeRangeAnimation,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        PianoRollStemEditorPointerEvent createEditorPointerEvent(
          PointerEvent rawEvent,
        ) {
          return PianoRollStemEditorPointerEvent(
            offset: pixelsToTime(
              timeViewStart: viewModel.timeRange.start,
              timeViewEnd: viewModel.timeRange.end,
              viewPixelWidth: constraints.maxWidth,
              pixelOffsetFromLeft: rawEvent.localPosition.dx,
            ),
            normalizedY:
                (1 - (rawEvent.localPosition.dy / constraints.maxHeight)).clamp(
                  0,
                  1,
                ),
            viewSize: constraints.biggest,
            pointer: rawEvent.pointer,
          );
        }

        return Container(
          color: AnthemTheme.grid.backgroundLight,
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
            child: ClipRect(
              child: CustomPaint(
                painter: _PianoRollStemPainter(
                  repaint: timeRangeAnimation.controller,
                  viewModel: viewModel,
                  project: project,
                  timeRangeAnimation: timeRangeAnimation,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PianoRollStemPainter extends CustomPainterObserver {
  PianoRollViewModel viewModel;
  ProjectModel project;
  TimeRangeAnimation timeRangeAnimation;

  _PianoRollStemPainter({
    required Listenable repaint,
    required this.viewModel,
    required this.project,
    required this.timeRangeAnimation,
  }) : super(debugName: '_PianoRollStemPainter', repaint: repaint);

  double get timeViewStart => timeRangeAnimation.renderedStart;
  double get timeViewEnd => timeRangeAnimation.renderedEnd;

  @override
  void observablePaint(Canvas canvas, Size size) {
    final minorLinePaint = Paint()..color = AnthemTheme.grid.minor;

    final colorShifter = AnthemColorShifter(AnthemTheme.primary.main);

    final selectedNoteColor = colorShifter.noteHovered;
    final noteColor = colorShifter.noteBase;
    final selectedNoteCircleColor = colorShifter.noteBase;
    final noteCircleColor = colorShifter.noteSelected;

    final selectedNotePaint = Paint()..color = selectedNoteColor;
    final notePaint = Paint()..color = noteColor;
    final selectedNoteCirclePaint = Paint()..color = selectedNoteCircleColor;
    final noteCirclePaint = Paint()..color = noteCircleColor;

    final activePattern =
        project.sequence.patterns[project.sequence.activePatternID];
    final selectedStem = viewModel.activeStem;

    int bottom;
    int baseline;
    int top;

    switch (selectedStem) {
      case PianoRollStem.velocity:
        bottom = PianoRollStem.velocity.bottom;
        baseline = PianoRollStem.velocity.baseline;
        top = PianoRollStem.velocity.top;
        break;
      case PianoRollStem.pan:
        bottom = PianoRollStem.pan.bottom;
        baseline = PianoRollStem.pan.baseline;
        top = PianoRollStem.pan.top;
        break;
    }

    paintTimeGridPhraseShading(
      canvas: canvas,
      size: size,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
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

    paintTimeGridLines(
      canvas: canvas,
      size: size,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      snap: AutoSnap(),
      baseTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: activePattern?.timeSignatureChanges ?? [],
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    if (activePattern == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0x88404040),
      );
      paintEditorLeftEdgeBorder(canvas, size);
      return;
    }

    final notes = activePattern.notes;
    final noteOverrides = activePattern.noteOverrides;
    final previewNotes = activePattern.previewNotes;

    notes.observeAllChanges();
    noteOverrides.observeAllChanges();
    previewNotes.observeAllChanges();

    // Redrawing the stem editor on any note change is cheaper than
    // observing every resolved note field individually while traversing the
    // full note set.
    blockObservation(
      modelItems: [notes, noteOverrides, previewNotes],
      block: () {
        for (final note in activePattern.renderOrderedResolvedNotes) {
          double stemValue;

          switch (selectedStem) {
            case PianoRollStem.velocity:
              stemValue = note.velocity;
              break;
            case PianoRollStem.pan:
              stemValue = note.pan;
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

          final isSelected = viewModel.selectedNotes.contains(note.id);

          final paint = isSelected ? selectedNotePaint : notePaint;
          final circleCenterPaint = isSelected
              ? selectedNoteCirclePaint
              : noteCirclePaint;

          double valueToPixels(num value) =>
              ((1 - ((value - bottom) / (top - bottom))) * size.height)
                  .round()
                  .toDouble();

          final barTop = valueToPixels(stemValue);
          final barBottom = valueToPixels(baseline);

          canvas.drawRect(
            Rect.fromPoints(
              Offset(startX, barTop),
              Offset(startX + 3, barBottom),
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
      },
    );

    paintEditorLeftEdgeBorder(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _PianoRollStemPainter oldDelegate) {
    return viewModel != oldDelegate.viewModel ||
        project != oldDelegate.project ||
        timeRangeAnimation != oldDelegate.timeRangeAnimation;
  }
}
