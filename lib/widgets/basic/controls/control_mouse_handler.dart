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
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:window_manager/window_manager.dart';

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

  final MouseCursor cursor;

  const ControlMouseHandler({
    super.key,
    this.child,
    this.onStart,
    this.onEnd,
    this.onChange,
    this.cursor = MouseCursor.defer,
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

  MouseCursorManager manager = MouseCursorManager(SystemMouseCursors.basic);

  void onPointerDown(PointerEvent e) async {
    final mediaQuery = MediaQuery.of(context);
    devicePixelRatio = mediaQuery.devicePixelRatio;

    final windowPos = await windowManager.getPosition();
    final windowSize = await windowManager.getSize();

    windowRect = Rect.fromLTWH(
      windowPos.dx / devicePixelRatio,
      windowPos.dy / devicePixelRatio,
      windowSize.width / devicePixelRatio,
      windowSize.height / devicePixelRatio,
    );

    final mousePos = Offset(
      e.position.dx + windowRect.left,
      e.position.dy + windowRect.top,
    );
    originalMouseX = mousePos.dx;
    originalMouseY = mousePos.dy;
    mostRecentMouseX = mousePos.dx;
    mostRecentMouseY = mousePos.dy;

    widget.onStart?.call();
  }

  void onPointerMove(PointerLockMoveEvent e) {
    accumulatorX += e.delta.dx;
    accumulatorY += e.delta.dy;

    widget.onChange?.call(
      ControlMouseEvent(
        delta: Offset(e.delta.dx, -e.delta.dy),
        absolute: Offset(accumulatorX, -accumulatorY),
      ),
    );
  }

  void onPointerUp(PointerEvent e) {
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
      final keyboardModifiers = Provider.of<KeyboardModifiers>(
        context,
        listen: false,
      );

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
    final listener = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: onPointerUp,
      onPointerSignal: onPointerSignal,
      child: widget.child,
    );

    final lock = PointerLockDragArea(
      windowsMode: PointerLockWindowsMode.capture,
      onLock: (e) {
        onPointerDown(e.trigger);
      },
      onMove: (e) {
        onPointerMove(e.move);
      },
      onUnlock: (e) {
        onPointerUp(e.trigger);
        setState(() {});
      },
      cursor: PointerLockCursor.hidden,
      child: listener,
    );

    return MouseRegion(cursor: widget.cursor, child: lock);
  }
}
