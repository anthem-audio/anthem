/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/shared/timeline_cubit.dart';
import 'package:anthem/widgets/main_window/main_window_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:provider/provider.dart';

import 'helpers/time_helpers.dart';
import 'helpers/types.dart';

class Timeline extends StatefulWidget {
  const Timeline({Key? key}) : super(key: key);

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  double dragStartPixelValue = -1.0;
  double dragStartTimeViewStartValue = -1.0;
  double dragStartTimeViewEndValue = -1.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, state) {
        var timeView = context.watch<TimeView>();

        return Listener(
          onPointerDown: (e) {
            dragStartPixelValue = e.localPosition.dx;
            dragStartTimeViewStartValue = timeView.start;
            dragStartTimeViewEndValue = timeView.end;
          },
          onPointerMove: (e) {
            final keyboardModifiers =
                Provider.of<KeyboardModifiers>(context, listen: false);
            if (!keyboardModifiers.alt) {
              final viewWidth = context.size?.width;
              if (viewWidth == null) return;

              var pixelsPerTick = viewWidth / (timeView.end - timeView.start);
              final tickDelta =
                  (e.localPosition.dx - dragStartPixelValue) / pixelsPerTick;
              timeView.setStart(dragStartTimeViewStartValue - tickDelta);
              timeView.setEnd(dragStartTimeViewEndValue - tickDelta);
            } else {
              final oldSize =
                  dragStartTimeViewEndValue - dragStartTimeViewStartValue;
              final newSize = oldSize *
                  pow(2, 0.01 * (dragStartPixelValue - e.localPosition.dx));
              final delta = newSize - oldSize;
              timeView.setStart(dragStartTimeViewStartValue - delta * 0.5);
              timeView.setEnd(dragStartTimeViewEndValue + delta * 0.5);
            }
          },
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Theme.panel.accent,
                  child: ClipRect(
                    child: CustomPaint(
                      painter: TimelinePainter(
                        timeViewStart: timeView.start,
                        timeViewEnd: timeView.end,
                        ticksPerQuarter: state.ticksPerQuarter,
                        defaultTimeSignature: state.defaultTimeSignature,
                        timeSignatureChanges: state.timeSignatureChanges,
                      ),
                    ),
                  ),
                ),
                CustomMultiChildLayout(
                  children: (state.timeSignatureChanges)
                      .map(
                        (change) => LayoutId(
                          id: change.offset,
                          child: TimelineLabel(
                            text:
                                "${change.timeSignature.numerator}/${change.timeSignature.denominator}",
                          ),
                        ),
                      )
                      .toList(),
                  delegate: TimeSignatureLabelLayoutDelegate(
                    timeSignatureChanges: state.timeSignatureChanges,
                    timeViewStart: timeView.start,
                    timeViewEnd: timeView.end,
                    // viewPixelWidth:
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TimeSignatureLabelLayoutDelegate extends MultiChildLayoutDelegate {
  TimeSignatureLabelLayoutDelegate({
    required this.timeSignatureChanges,
    required this.timeViewStart,
    required this.timeViewEnd,
    // required this.viewPixelWidth,
  });

  List<TimeSignatureChangeModel> timeSignatureChanges;
  double timeViewStart;
  double timeViewEnd;
  // double viewPixelWidth;

  @override
  void performLayout(Size size) {
    for (var change in timeSignatureChanges) {
      layoutChild(
        change.offset,
        BoxConstraints(
          maxWidth: size.width,
          maxHeight: size.height,
        ),
      );

      var x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: change.offset.toDouble(),
      );

      positionChild(change.offset, Offset(x, 21));
    }
  }

  @override
  bool shouldRelayout(TimeSignatureLabelLayoutDelegate oldDelegate) {
    // This compares two lists. I have no idea if that makes sense in flutter
    // but we may get a stale layout doing that.
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.timeSignatureChanges != timeSignatureChanges;
  }
}

class TimelineLabel extends StatelessWidget {
  const TimelineLabel({Key? key, required this.text}) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: const Color(0xFFFFFFFF).withOpacity(0.6),
          width: 2,
          height: 21,
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withOpacity(0.08),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(3),
            ),
          ),
          child: Text(text),
          padding: const EdgeInsets.only(left: 4, right: 4),
          height: 21,
        ),
      ],
    );
  }
}

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.defaultTimeSignature,
    required this.timeSignatureChanges,
  });

  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final TimeSignatureModel defaultTimeSignature;
  final List<TimeSignatureChangeModel> timeSignatureChanges;

  @override
  void paint(Canvas canvas, Size size) {
    var divisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: 32,
      snap: BarSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    var i = 0;
    var timePtr =
        (timeViewStart / divisionChanges[0].divisionRenderSize).floor() *
            divisionChanges[0].divisionRenderSize;
    var barNumber = divisionChanges[0].startLabel;

    barNumber += (timePtr /
            (divisionChanges[0].divisionRenderSize /
                divisionChanges[0].distanceBetween))
        .floor();

    while (timePtr < timeViewEnd) {
      // This shouldn't happen, but safety first
      if (i >= divisionChanges.length) break;

      final thisDivision = divisionChanges[i];
      var nextDivisionStart = 0x7FFFFFFFFFFFFFFF; // int max

      if (i < divisionChanges.length - 1) {
        nextDivisionStart = divisionChanges[i + 1].offset;
      }

      if (timePtr >= nextDivisionStart) {
        timePtr = nextDivisionStart;
        barNumber = divisionChanges[i + 1].startLabel;
        i++;
        continue;
      }

      while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
        final x = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: timePtr.toDouble());

        TextSpan span = TextSpan(
            style: TextStyle(color: Theme.text.main),
            text: barNumber.toString());
        TextPainter textPainter = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        textPainter.layout();
        // TODO: replace height constant
        textPainter.paint(
            canvas, Offset(x, (21 - textPainter.size.height) / 2));

        timePtr += thisDivision.divisionRenderSize;
        barNumber += thisDivision.distanceBetween;
      }

      i++;
    }
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) {
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd;
  }

  @override
  bool shouldRebuildSemantics(TimelinePainter oldDelegate) => false;
}
