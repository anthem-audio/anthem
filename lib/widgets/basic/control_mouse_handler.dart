/*
  Copyright (C) 2022 Joshua Wade

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

import 'dart:async';

import 'package:anthem/main.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ControlMouseEvent {
  Offset delta;
  Offset absolute;

  ControlMouseEvent({required this.delta, required this.absolute});
}

enum _AxisHandlerStatus {
  idle,
  waitingForNegativeJump,
  waitingForPositiveJump,
  waitingForZoneExit,
}

enum _JumpDirection { positive, negative }

class ControlMouseHandler extends StatefulWidget {
  final Widget? child;
  final Function? onStart;
  final Function(ControlMouseEvent event)? onEnd;
  final Function(ControlMouseEvent event)? onChange;

  const ControlMouseHandler({
    Key? key,
    this.child,
    this.onStart,
    this.onEnd,
    this.onChange,
  }) : super(key: key);

  @override
  State<ControlMouseHandler> createState() => _ControlMouseHandlerState();
}

class _ControlMouseHandlerState extends State<ControlMouseHandler> {
  Rect windowRect = Rect.zero;

  double devicePixelRatio = -1;

  double originalMouseX = -1;
  double originalMouseY = -1;

  double mostRecentMouseX = -1;
  double mostRecentMouseY = -1;

  double accumulatorX = 0;
  double accumulatorY = 0;

  // Size of the region we use to detect if the mouse has successfully jumped
  double jumpDetectionAreaSize = 30;

  // If the mouse is less than this far from the edge of the window, we jump
  double jumpMouseAreaSize = 30;

  // State machine for managing mouse jumps
  _AxisHandlerStatus horizontalAxisState = _AxisHandlerStatus.idle;
  _AxisHandlerStatus verticalAxisState = _AxisHandlerStatus.idle;

  MouseCursor cursor = MouseCursor.defer;

  MouseCursorManager manager = MouseCursorManager(
    SystemMouseCursors.basic,
  );

  @override
  Widget build(BuildContext context) {
    final child = Listener(
      onPointerDown: (e) async {
        final mediaQuery = MediaQuery.of(context);
        windowRect = Rect.fromLTRB(
          appWindow.rect.left / devicePixelRatio,
          appWindow.rect.top / devicePixelRatio,
          appWindow.rect.right / devicePixelRatio,
          appWindow.rect.bottom / devicePixelRatio,
        );
        devicePixelRatio = mediaQuery.devicePixelRatio;

        final mousePos = Offset(
            e.position.dx + windowRect.left, e.position.dy + windowRect.top);
        originalMouseX = mousePos.dx;
        originalMouseY = mousePos.dy;
        mostRecentMouseX = mousePos.dx;
        mostRecentMouseY = mousePos.dy;

        widget.onStart?.call();
      },
      onPointerUp: (e) {
        api.setMousePos(
          x: (originalMouseX * devicePixelRatio).round(),
          y: (originalMouseY * devicePixelRatio).round(),
        );

        widget.onEnd?.call(
          ControlMouseEvent(
            delta: const Offset(0, 0),
            absolute: Offset(accumulatorX, accumulatorY),
          ),
        );

        accumulatorX = 0;
        accumulatorY = 0;

        horizontalAxisState = _AxisHandlerStatus.idle;
        verticalAxisState = _AxisHandlerStatus.idle;
      },
      onPointerMove: (e) async {
        final mousePos = Offset(
            e.position.dx + windowRect.left, e.position.dy + windowRect.top);
        final mouseX = mousePos.dx;
        final mouseY = mousePos.dy;

        final dx = (mouseX - mostRecentMouseX) / devicePixelRatio;
        final dy = (mouseY - mostRecentMouseY) / devicePixelRatio;

        final isInLeftJumpDetectZone =
            mouseX - windowRect.left < jumpMouseAreaSize;
        final isInTopJumpDetectZone =
            mouseY - windowRect.top < jumpMouseAreaSize;
        final isInRightJumpDetectZone =
            windowRect.right - mouseX < jumpMouseAreaSize;
        final isInBottomJumpDetectZone =
            windowRect.bottom - mouseY < jumpMouseAreaSize;

        final isInLeftJumpTargetZone =
            mouseX - windowRect.left < jumpDetectionAreaSize;
        final isInTopJumpTargetZone =
            mouseY - windowRect.top < jumpDetectionAreaSize;
        final isInRightJumpTargetZone =
            windowRect.right - mouseX < jumpDetectionAreaSize;
        final isInBottomJumpTargetZone =
            windowRect.bottom - mouseY < jumpDetectionAreaSize;

        _JumpDirection? xJumpDirection;
        _JumpDirection? yJumpDirection;

        final isWaitingForHorizontalJump = horizontalAxisState ==
                _AxisHandlerStatus.waitingForNegativeJump ||
            horizontalAxisState == _AxisHandlerStatus.waitingForPositiveJump;
        final isWaitingForVerticalJump =
            verticalAxisState == _AxisHandlerStatus.waitingForNegativeJump ||
                verticalAxisState == _AxisHandlerStatus.waitingForPositiveJump;

        // Horizontal axis jump detection
        if (horizontalAxisState == _AxisHandlerStatus.waitingForZoneExit) {
          accumulatorX += dx;

          if (!isInLeftJumpTargetZone && !isInRightJumpTargetZone) {
            horizontalAxisState = _AxisHandlerStatus.idle;
          }
        } else if (horizontalAxisState ==
                _AxisHandlerStatus.waitingForNegativeJump ||
            horizontalAxisState == _AxisHandlerStatus.waitingForPositiveJump) {
          if (horizontalAxisState ==
                  _AxisHandlerStatus.waitingForNegativeJump &&
              !isInRightJumpTargetZone) {
            horizontalAxisState = _AxisHandlerStatus.waitingForZoneExit;
          }
          if (horizontalAxisState ==
                  _AxisHandlerStatus.waitingForPositiveJump &&
              !isInLeftJumpTargetZone) {
            horizontalAxisState = _AxisHandlerStatus.waitingForZoneExit;
          }
        } else if (horizontalAxisState == _AxisHandlerStatus.idle) {
          accumulatorX += dx;

          if (isInLeftJumpDetectZone) {
            horizontalAxisState = _AxisHandlerStatus.waitingForPositiveJump;
            xJumpDirection = _JumpDirection.positive;
          } else if (isInRightJumpDetectZone) {
            horizontalAxisState = _AxisHandlerStatus.waitingForNegativeJump;
            xJumpDirection = _JumpDirection.negative;
          }
        }

        // Vertical axis jump detection
        if (verticalAxisState == _AxisHandlerStatus.waitingForZoneExit) {
          accumulatorY += dy;

          if (!isInTopJumpTargetZone && !isInBottomJumpTargetZone) {
            verticalAxisState = _AxisHandlerStatus.idle;
          }
        } else if (verticalAxisState ==
                _AxisHandlerStatus.waitingForNegativeJump ||
            verticalAxisState == _AxisHandlerStatus.waitingForPositiveJump) {
          if (verticalAxisState == _AxisHandlerStatus.waitingForNegativeJump &&
              !isInBottomJumpTargetZone) {
            verticalAxisState = _AxisHandlerStatus.waitingForZoneExit;
          }
          if (verticalAxisState == _AxisHandlerStatus.waitingForPositiveJump &&
              !isInTopJumpTargetZone) {
            verticalAxisState = _AxisHandlerStatus.waitingForZoneExit;
          }
        } else if (verticalAxisState == _AxisHandlerStatus.idle) {
          accumulatorY += dy;

          if (isInTopJumpDetectZone) {
            verticalAxisState = _AxisHandlerStatus.waitingForPositiveJump;
            yJumpDirection = _JumpDirection.positive;
          } else if (isInBottomJumpDetectZone) {
            verticalAxisState = _AxisHandlerStatus.waitingForNegativeJump;
            yJumpDirection = _JumpDirection.negative;
          }
        }

        if (xJumpDirection != null || yJumpDirection != null) {
          var x = mouseX;
          var y = mouseY;

          if (xJumpDirection == _JumpDirection.positive) {
            x = windowRect.right - jumpMouseAreaSize;
          } else if (xJumpDirection == _JumpDirection.negative) {
            x = windowRect.left + jumpMouseAreaSize;
          }

          if (yJumpDirection == _JumpDirection.positive) {
            y = windowRect.bottom - jumpMouseAreaSize;
          } else if (yJumpDirection == _JumpDirection.negative) {
            y = windowRect.top + jumpMouseAreaSize;
          }

          x *= devicePixelRatio;
          y *= devicePixelRatio;

          api.setMousePos(x: x.round(), y: y.round());
        }

        widget.onChange?.call(
          ControlMouseEvent(
            delta: Offset(isWaitingForHorizontalJump ? 0 : dx,
                isWaitingForVerticalJump ? 0 : dy),
            absolute: Offset(accumulatorX, accumulatorY),
          ),
        );

        mostRecentMouseX = mouseX;
        mostRecentMouseY = mouseY;
      },
      child: widget.child,
    );

    return cursor == SystemMouseCursors.none
        ? MouseRegion(
            cursor: cursor,
            child: child,
          )
        : child;
  }
}
