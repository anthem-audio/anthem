/*
  Copyright (C) 2021 - 2023 Joshua Wade

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
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/grid_paint_helpers.dart';
import '../shared/helpers/types.dart';
import 'helpers.dart';

class PianoRollGrid extends StatelessWidget {
  final double keyHeight;
  final AnimationController timeViewAnimationController;
  final AnimationController keyValueAtTopAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Animation<double> keyValueAtTopAnimation;

  const PianoRollGrid({
    Key? key,
    required this.keyHeight,
    required this.keyValueAtTopAnimationController,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.keyValueAtTopAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final pattern = project.song.patterns[project.song.activePatternID];

    return ClipRect(
      child: AnimatedBuilder(
        animation: keyValueAtTopAnimationController,
        builder: (context, child) {
          return AnimatedBuilder(
            animation: timeViewAnimationController,
            builder: (context, child) {
              return Observer(builder: (context) {
                return CustomPaint(
                  painter: PianoRollBackgroundPainter(
                    keyHeight: keyHeight,
                    keyValueAtTop: keyValueAtTopAnimation.value,
                    timeViewStart: timeViewStartAnimation.value,
                    timeViewEnd: timeViewEndAnimation.value,
                    ticksPerQuarter: project.song.ticksPerQuarter,
                    defaultTimeSignature: pattern?.defaultTimeSignature,
                    timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
                  ),
                );
              });
            },
          );
        },
      ),
    );
  }
}

class PianoRollBackgroundPainter extends CustomPainter {
  PianoRollBackgroundPainter({
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.defaultTimeSignature,
    required this.timeSignatureChanges,
  });

  final double keyHeight;
  final double keyValueAtTop;
  final TimeSignatureModel? defaultTimeSignature;
  final List<TimeSignatureChangeModel> timeSignatureChanges;
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    var minorLinePaint = Paint()..color = Theme.grid.minor;

    var lightBackgroundPaint = Paint()..color = Theme.grid.backgroundLight;
    var darkBackgroundPaint = Paint()..color = Theme.grid.backgroundDark;

    // Background

    var keyNum = keyValueAtTop.ceil();

    while (true) {
      final y = (keyValueAtTop - keyNum) * keyHeight;

      if (y > size.height) break;

      final keyType = getKeyType(keyNum - 1);
      final backgroundStripRect = Rect.fromLTWH(0, y, size.width, keyHeight);
      if (keyType == KeyType.white) {
        canvas.drawRect(backgroundStripRect, lightBackgroundPaint);
      } else {
        canvas.drawRect(backgroundStripRect, darkBackgroundPaint);
      }
      keyNum--;
    }

    // Horizontal lines

    var linePointer = ((keyValueAtTop * keyHeight) % keyHeight);

    while (linePointer < size.height) {
      canvas.drawRect(
          Rect.fromLTWH(0, linePointer, size.width, 1), minorLinePaint);
      linePointer += keyHeight;
    }

    // Vertical lines

    paintTimeGrid(
      canvas: canvas,
      size: size,
      ticksPerQuarter: ticksPerQuarter,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      baseTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
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
