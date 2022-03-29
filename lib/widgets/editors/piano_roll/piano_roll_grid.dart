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

import 'package:anthem/model/pattern.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:provider/provider.dart';

import '../../../model/project.dart';
import '../../../model/store.dart';
import 'helpers.dart';

class PianoRollGrid extends StatelessWidget {
  const PianoRollGrid({
    Key? key,
    required this.keyHeight,
    required this.keyValueAtTop,
  }) : super(key: key);

  final double keyValueAtTop;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PianoRollCubit, PianoRollState>(
        builder: (context, state) {
      final pattern = Store.instance.projects[state.projectID]?.song.patterns[state.patternID];
      final timeView = context.watch<TimeView>();

      return ClipRect(
        child: CustomPaint(
          painter: PianoRollBackgroundPainter(
            keyHeight: keyHeight,
            keyValueAtTop: keyValueAtTop,
            pattern: pattern,
            timeViewStart: timeView.start,
            timeViewEnd: timeView.end,
            ticksPerQuarter: state.ticksPerQuarter,
          ),
        ),
      );
    });
  }
}

class PianoRollBackgroundPainter extends CustomPainter {
  PianoRollBackgroundPainter({
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.pattern,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
  });

  final double keyHeight;
  final double keyValueAtTop;
  final PatternModel? pattern;
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;

  @override
  void paint(Canvas canvas, Size size) {
    var black = Paint();
    black.color = const Color(0xFF000000);

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000).withOpacity(0.2),
    );

    // Horizontal lines

    var linePointer = ((keyValueAtTop * keyHeight) % keyHeight);

    while (linePointer < size.height) {
      canvas.drawRect(Rect.fromLTWH(0, linePointer, size.width, 1), black);
      linePointer += keyHeight;
    }

    // Vertical lines

    var minorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: 8,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      defaultTimeSignature: pattern?.defaultTimeSignature,
      timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: minorDivisionChanges,
      size: size,
      paint: black,
    );

    // Draws everything since canvas.saveLayer() with the color provided in
    // canvas.saveLayer(). This means that overlapping lines won't be darker,
    // even though the whole thing is rendered with opacity.
    canvas.restore();

    var majorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: 20,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 1)),
      defaultTimeSignature: pattern?.defaultTimeSignature,
      timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    var majorVerticalLinePaint = Paint()
      ..color = const Color(0xFF000000).withOpacity(0.22);

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: majorDivisionChanges,
      size: size,
      paint: majorVerticalLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant PianoRollBackgroundPainter oldDelegate) {
    return oldDelegate.keyHeight != keyHeight ||
        oldDelegate.keyValueAtTop != keyValueAtTop ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd;
  }
}

void paintVerticalLines({
  required Canvas canvas,
  required double timeViewStart,
  required double timeViewEnd,
  required List<DivisionChange> divisionChanges,
  required Size size,
  required Paint paint,
}) {
  var i = 0;
  // There should always be at least one division change. The first change
  // should always represent the base time signature for the pattern (or the
  // first time signature change, if its position is 0).
  var timePtr =
      (timeViewStart / divisionChanges[0].divisionRenderSize).floor() *
          divisionChanges[0].divisionRenderSize;

  while (timePtr < timeViewEnd) {
    // This shouldn't happen, but safety first
    if (i >= divisionChanges.length) break;

    var thisDivision = divisionChanges[i];
    var nextDivisionStart = 0x7FFFFFFFFFFFFFFF; // int max

    if (i < divisionChanges.length - 1) {
      nextDivisionStart = divisionChanges[i + 1].offset;
    }

    if (timePtr >= nextDivisionStart) {
      timePtr = nextDivisionStart;
      i++;
      continue;
    }

    while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
      var x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: timePtr.toDouble());

      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);

      timePtr += thisDivision.divisionRenderSize;
    }

    i++;
  }
}
