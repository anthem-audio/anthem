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

/*
  This is a mouse handler for controls, like knobs and sliders.
  
  It renders a mouse area. On mouse down, it makes the cursor invisible and
  moves it to the center of the screen. It then captures any movement and
  reports it via callbacks. When the user releases the mouse, the cursor is
  moved back to where it was when the mouse was pressed.
*/

import 'dart:async';

import 'package:anthem/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ControlMouseEvent {
  Offset delta;
  Offset absolute;

  ControlMouseEvent({required this.delta, required this.absolute});
}

enum _HandlerStatus {
  waitingForCenter,
  waitingForMove,
}

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
  int deadPointX = -1;
  int deadPointY = -1;

  double devicePixelRatio = -1;

  int originalMouseX = -1;
  int originalMouseY = -1;

  double accumulatorX = 0;
  double accumulatorY = 0;

  _HandlerStatus status = _HandlerStatus.waitingForCenter;

  MouseCursor cursor = MouseCursor.defer;

  MouseCursorManager manager = MouseCursorManager(
    SystemMouseCursors.basic,
  );

  @override
  Widget build(BuildContext context) {
    final child = Listener(
      onPointerDown: (e) async {
        final mediaQuery = MediaQuery.of(context);
        final windowSize = mediaQuery.size;
        devicePixelRatio = mediaQuery.devicePixelRatio;
      
        // The screen is probably bigger than half the window width / height
        deadPointX = (windowSize.width * devicePixelRatio / 2).round();
        deadPointY = (windowSize.height * devicePixelRatio / 2).round();
      
        final mousePos = await api.getMousePos();
        originalMouseX = mousePos.x;
        originalMouseY = mousePos.y;
      
        api.setMousePos(x: deadPointX, y: deadPointY);
      
        widget.onStart?.call();

        (() async {
          await Future.delayed(const Duration(seconds: 1));
          manager.handleDeviceCursorUpdate(0, null, [SystemMouseCursors.none]);
        })();
      },
      onPointerUp: (e) {
        api.setMousePos(x: originalMouseX, y: originalMouseY);
      
        widget.onEnd?.call(
          ControlMouseEvent(
            delta: const Offset(0, 0),
            absolute: Offset(accumulatorX, accumulatorY),
          ),
        );
      
        accumulatorX = 0;
        accumulatorY = 0;
      },
      onPointerMove: (e) async {
        final mousePos = await api.getMousePos();
        if (status == _HandlerStatus.waitingForCenter) {
          if (mousePos.x == deadPointX && mousePos.y == deadPointY) {
            status = _HandlerStatus.waitingForMove;
          } else {
            api.setMousePos(x: deadPointX, y: deadPointY);
          }
          return;
        }
      
        final dx = (mousePos.x - deadPointX) / devicePixelRatio;
        final dy = (mousePos.y - deadPointY) / devicePixelRatio;
      
        accumulatorX += dx;
        accumulatorY += dy;
      
        api.setMousePos(x: deadPointX, y: deadPointY);
      
        widget.onChange?.call(
          ControlMouseEvent(
            delta: Offset(dx, dy),
            absolute: Offset(accumulatorX, accumulatorY),
          ),
        );
      },
      child: widget.child,
    );

    return cursor == SystemMouseCursors.none ? MouseRegion(
      cursor: cursor,
      child: child,
    ) : child;
  }
}
