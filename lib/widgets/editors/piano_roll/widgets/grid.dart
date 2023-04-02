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
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../shared/helpers/grid_paint_helpers.dart';
import '../../shared/helpers/types.dart';
import '../helpers.dart';

class PianoRollGrid extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final AnimationController keyValueAtTopAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Animation<double> keyValueAtTopAnimation;

  const PianoRollGrid({
    Key? key,
    required this.keyValueAtTopAnimationController,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.keyValueAtTopAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return ClipRect(
      child: AnimatedBuilder(
        animation: keyValueAtTopAnimationController,
        builder: (context, child) {
          return AnimatedBuilder(
            animation: timeViewAnimationController,
            builder: (context, child) {
              return CustomPaintObserver(
                painterBuilder: () => PianoRollBackgroundPainter(
                  project: project,
                  viewModel: viewModel,
                  keyValueAtTop: keyValueAtTopAnimation.value,
                  timeViewStart: timeViewStartAnimation.value,
                  timeViewEnd: timeViewEndAnimation.value,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PianoRollBackgroundPainter extends CustomPainterObserver {
  PianoRollBackgroundPainter({
    required this.project,
    required this.viewModel,
    required this.keyValueAtTop,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final double keyValueAtTop;
  final double timeViewStart;
  final double timeViewEnd;

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    var minorLinePaint = Paint()..color = Theme.grid.minor;

    var lightBackgroundPaint = Paint()..color = Theme.grid.backgroundLight;
    var darkBackgroundPaint = Paint()..color = Theme.grid.backgroundDark;

    // Background

    var keyNum = keyValueAtTop.ceil();

    while (true) {
      final y = (keyValueAtTop - keyNum) * viewModel.keyHeight;

      if (y > size.height) break;

      final keyType = getKeyType(keyNum - 1);
      final backgroundStripRect =
          Rect.fromLTWH(0, y, size.width, viewModel.keyHeight);
      if (keyType == KeyType.white) {
        canvas.drawRect(backgroundStripRect, lightBackgroundPaint);
      } else {
        canvas.drawRect(backgroundStripRect, darkBackgroundPaint);
      }
      keyNum--;
    }

    // Horizontal lines

    var linePointer =
        ((keyValueAtTop * viewModel.keyHeight) % viewModel.keyHeight);

    while (linePointer < size.height) {
      canvas.drawRect(
          Rect.fromLTWH(0, linePointer, size.width, 1), minorLinePaint);
      linePointer += viewModel.keyHeight;
    }

    // Vertical lines

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
  }

  @override
  bool shouldRepaint(covariant PianoRollBackgroundPainter oldDelegate) {
    return project != oldDelegate.project ||
        viewModel != oldDelegate.viewModel ||
        keyValueAtTop != oldDelegate.keyValueAtTop ||
        timeViewStart != oldDelegate.timeViewStart ||
        timeViewEnd != oldDelegate.timeViewEnd ||
        super.shouldRepaint(oldDelegate);
  }
}
