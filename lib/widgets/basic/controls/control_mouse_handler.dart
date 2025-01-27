/*
  Copyright (C) 2022 - 2025 Joshua Wade

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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ControlMouseEvent {
  Offset delta;
  Offset absolute;

  ControlMouseEvent({required this.delta, required this.absolute});
}

class ControlMouseHandler extends StatefulWidget {
  final Widget? child;
  final void Function()? onStart;
  final void Function(ControlMouseEvent event)? onEnd;
  final void Function(ControlMouseEvent event)? onChange;

  final bool allowHorizontalJump;
  final bool allowVerticalJump;

  const ControlMouseHandler({
    super.key,
    this.child,
    this.onStart,
    this.onEnd,
    this.onChange,
    this.allowHorizontalJump = true,
    this.allowVerticalJump = true,
  });

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

  // If the mouse is less than this far from the edge of the window, we jump
  double jumpMouseAreaSize = 30;

  // When we jump, we jump to (screen edge) + jumpMouseAreaSize + jumpPadding
  double jumpPadding = 20;

  MouseCursor cursor = MouseCursor.defer;

  MouseCursorManager manager = MouseCursorManager(
    SystemMouseCursors.basic,
  );

  void onPointerDown(PointerEvent e) {
    final mediaQuery = MediaQuery.of(context);
    devicePixelRatio = mediaQuery.devicePixelRatio;
    windowRect = Rect.fromLTRB(
      appWindow.rect.left / devicePixelRatio,
      appWindow.rect.top / devicePixelRatio,
      appWindow.rect.right / devicePixelRatio,
      appWindow.rect.bottom / devicePixelRatio,
    );

    final mousePos =
        Offset(e.position.dx + windowRect.left, e.position.dy + windowRect.top);
    originalMouseX = mousePos.dx;
    originalMouseY = mousePos.dy;
    mostRecentMouseX = mousePos.dx;
    mostRecentMouseY = mousePos.dy;

    widget.onStart?.call();
  }

  void onPointerMove(PointerEvent e) {
    final mousePos =
        Offset(e.position.dx + windowRect.left, e.position.dy + windowRect.top);
    final mouseX = mousePos.dx;
    final mouseY = mousePos.dy;

    final dx = (mouseX - mostRecentMouseX);
    final dy = (mouseY - mostRecentMouseY);

    accumulatorX += dx;
    accumulatorY += dy;

    widget.onChange?.call(
      ControlMouseEvent(
        delta: Offset(dx, -dy),
        absolute: Offset(accumulatorX, -accumulatorY),
      ),
    );

    mostRecentMouseX = mouseX;
    mostRecentMouseY = mouseY;
  }

  void onPointerUp(PointerEvent e) {
    // We'll skip this for now, until we can figure out a way to make the
    // mouse cursor disappear.

    // api.setMousePos(
    //   x: (originalMouseX * devicePixelRatio).round(),
    //   y: (originalMouseY * devicePixelRatio).round(),
    // );

    widget.onEnd?.call(
      ControlMouseEvent(
        delta: const Offset(0, 0),
        absolute: Offset(accumulatorX, accumulatorY),
      ),
    );

    accumulatorX = 0;
    accumulatorY = 0;
  }

  void onPointerSignal(PointerEvent e) {
    if (e is PointerScrollEvent) {
      final keyboardModifiers =
          Provider.of<KeyboardModifiers>(context, listen: false);

      final dxRaw = -e.scrollDelta.dx * 0.35;
      final dyRaw = -e.scrollDelta.dy * 0.35;

      final dx = keyboardModifiers.shift ? dyRaw : dxRaw;
      final dy = keyboardModifiers.shift ? dxRaw : dyRaw;

      final event = ControlMouseEvent(
        delta: Offset(dx, dy),
        absolute: Offset(dx, dy),
      );

      widget.onStart?.call();
      widget.onChange?.call(event);
      widget.onEnd?.call(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerCancel: onPointerUp,
      onPointerSignal: onPointerSignal,
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
