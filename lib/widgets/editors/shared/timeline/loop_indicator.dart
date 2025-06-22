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

import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';

import 'timeline.dart';

class LoopIndicator extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Size timelineSize;
  final int? loopStart;
  final int? loopEnd;

  final void Function() onLoopStartPressed;
  final void Function() onLoopEndPressed;

  const LoopIndicator({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timelineSize,
    required this.loopStart,
    required this.loopEnd,
    required this.onLoopStartPressed,
    required this.onLoopEndPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timeViewAnimationController,
      builder: (context, child) {
        final timeViewStart = timeViewStartAnimation.value;
        final timeViewEnd = timeViewEndAnimation.value;

        final loopStartX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: timelineSize.width,
          time: loopStart?.toDouble() ?? 0.0,
        );

        final loopEndX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: timelineSize.width,
          time: loopEnd?.toDouble() ?? 0.0,
        );

        final handleInteractSize = 16.0;
        final handleSize = 3.0;

        return Visibility(
          visible: loopStart != null && loopEnd != null,
          child: Positioned(
            left: loopStartX - handleInteractSize / 2,
            top: 0,
            child: SizedBox(
              width: loopEndX - loopStartX + handleInteractSize,
              height: loopAreaHeight,
              child: Stack(
                children: [
                  // Main loop area
                  Positioned(
                    left: handleInteractSize / 2 + handleSize / 2,
                    right: handleInteractSize / 2 + handleSize / 2,
                    top: 0,
                    bottom: 0,
                    child: Container(color: Color(0xFF20A888).withAlpha(63)),
                  ),

                  // Loop start handle
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: handleInteractSize,
                      child: Listener(
                        onPointerDown: (event) {
                          onLoopStartPressed();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Center(
                            child: Container(
                              width: handleSize,
                              height: loopAreaHeight,
                              color: Color(0xFF20A888).withAlpha(200),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loop end handle
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: handleInteractSize,
                      child: Listener(
                        onPointerDown: (event) {
                          onLoopEndPressed();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Center(
                            child: Container(
                              width: handleSize,
                              height: loopAreaHeight,
                              color: Color(0xFF20A888).withAlpha(200),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
