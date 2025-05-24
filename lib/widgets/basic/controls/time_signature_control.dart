/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/commands/sequence_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/controls/control_mouse_handler.dart';
import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

/// A widget for controlling the time signature of the project sequence.
class TimeSignatureControl extends StatefulObserverWidget {
  const TimeSignatureControl({super.key});

  @override
  State<TimeSignatureControl> createState() => _TimeSignatureControlState();
}

class _TimeSignatureControlState extends State<TimeSignatureControl> {
  int startNumerator = -1;
  int startDenominatorIndex = -1;

  final List<int> validDenominators = const [1, 2, 4, 8, 16, 32];

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);

    final timeSignature = projectModel.sequence.defaultTimeSignature;

    final numeratorString = timeSignature.numerator.toString().padLeft(2);
    final denominatorString = timeSignature.denominator.toString().padRight(2);

    return Stack(
      children: [
        DigitDisplay(text: '$numeratorString / $denominatorString'),
        Positioned.fill(
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: ControlMouseHandler(
                  cursor: SystemMouseCursors.resizeUpDown,
                  onStart: () {
                    startNumerator = timeSignature.numerator;
                  },
                  onChange: (event) {
                    final newNumerator =
                        (startNumerator + event.absolute.dy / 50).round().clamp(
                          1,
                          32,
                        );

                    timeSignature.numerator = newNumerator;
                  },
                  onEnd: (event) {
                    if (timeSignature.numerator == startNumerator) {
                      return;
                    }

                    final command = SetTimeSignatureCommand(
                      oldNumerator: startNumerator,
                      oldDenominator: timeSignature.denominator,
                      newNumerator: timeSignature.numerator,
                      newDenominator: timeSignature.denominator,
                    );

                    projectModel.push(command);
                  },
                ),
              ),
              Expanded(
                child: ControlMouseHandler(
                  cursor: SystemMouseCursors.resizeUpDown,
                  onStart: () {
                    startDenominatorIndex = validDenominators.indexOf(
                      timeSignature.denominator,
                    );
                  },
                  onChange: (event) {
                    final newDenominatorIndex =
                        (startDenominatorIndex + event.absolute.dy / 50)
                            .round()
                            .clamp(0, validDenominators.length - 1);

                    timeSignature.denominator =
                        validDenominators[newDenominatorIndex];
                  },
                  onEnd: (event) {
                    if (validDenominators[startDenominatorIndex] ==
                        timeSignature.denominator) {
                      return;
                    }

                    final command = SetTimeSignatureCommand(
                      oldNumerator: timeSignature.numerator,
                      oldDenominator: validDenominators[startDenominatorIndex],
                      newNumerator: timeSignature.numerator,
                      newDenominator: timeSignature.denominator,
                    );

                    projectModel.push(command);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
