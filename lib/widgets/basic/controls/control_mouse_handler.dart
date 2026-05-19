/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/helpers/window_utils.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:pointer_lock/pointer_lock.dart';

const _doubleClickThreshold = Duration(milliseconds: 500);
const _maxDoubleClickDistance = 8.0;

class ControlMouseEvent {
  Offset delta;
  Offset absolute;
  PointerDeviceKind kind;

  /// Whether this event comes from a scroll (e.g. mouse wheel) or a drag.
  bool isScroll;

  ControlMouseEvent({
    required this.delta,
    required this.absolute,
    required this.kind,
    required this.isScroll,
  });
}

class ControlMouseHandler extends StatefulWidget {
  final Widget? child;
  final void Function()? onStart;
  final void Function(ControlMouseEvent event)? onEnd;
  final void Function(ControlMouseEvent event)? onChange;
  final VoidCallback? onDoubleClick;

  final MouseCursor cursor;

  /// Base hint text to display when the mouse is over this control.
  final String? baseHint;

  /// Optional function to provide a dynamic hint text during mouse interaction.
  ///
  /// If provided, this function will be called to get the hint text immediately
  /// after each onStart and onChange event.
  final String Function()? getHintText;

  const ControlMouseHandler({
    super.key,
    this.child,
    this.onStart,
    this.onEnd,
    this.onChange,
    this.onDoubleClick,
    this.cursor = MouseCursor.defer,
    this.baseHint,
    this.getHintText,
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

  PointerDeviceKind? pointerDeviceKind;

  int? baseHintId;
  int? changeHintId;

  Duration? _lastClickTimestamp;
  Offset? _lastClickPosition;
  Duration? _activeClickTimestamp;
  Offset? _activeClickPosition;
  bool _activeClickMoved = false;

  bool _isPrimaryButton(PointerDownEvent event) {
    return event.buttons & kPrimaryButton > 0;
  }

  bool _isWithinDoubleClickThreshold(Duration timestamp) {
    final lastClickTimestamp = _lastClickTimestamp;
    if (lastClickTimestamp == null) {
      return false;
    }

    final elapsed = timestamp - lastClickTimestamp;
    return elapsed >= Duration.zero && elapsed <= _doubleClickThreshold;
  }

  bool _qualifiesAsDoubleClick(PointerDownEvent event) {
    final lastClickPosition = _lastClickPosition;
    return widget.onDoubleClick != null &&
        lastClickPosition != null &&
        _isWithinDoubleClickThreshold(event.timeStamp) &&
        (event.position - lastClickPosition).distance <=
            _maxDoubleClickDistance;
  }

  void _clearPendingClick() {
    _lastClickTimestamp = null;
    _lastClickPosition = null;
  }

  void _clearActiveClick() {
    _activeClickTimestamp = null;
    _activeClickPosition = null;
    _activeClickMoved = false;
  }

  bool _acceptPointerLock(PointerLockDragAcceptDetails details) {
    final event = details.trigger;

    if (!_isPrimaryButton(event)) {
      _clearPendingClick();
      _clearActiveClick();
      return false;
    }

    if (_qualifiesAsDoubleClick(event)) {
      _clearPendingClick();
      _clearActiveClick();
      widget.onDoubleClick?.call();
      return false;
    }

    _activeClickTimestamp = event.timeStamp;
    _activeClickPosition = event.position;
    _activeClickMoved = false;

    return true;
  }

  void _recordActiveClick() {
    final activeClickTimestamp = _activeClickTimestamp;
    final activeClickPosition = _activeClickPosition;

    if (activeClickTimestamp != null &&
        activeClickPosition != null &&
        !_activeClickMoved) {
      _lastClickTimestamp = activeClickTimestamp;
      _lastClickPosition = activeClickPosition;
    } else {
      _clearPendingClick();
    }

    _clearActiveClick();
  }

  void onPointerDown(PointerEvent e) async {
    pointerDeviceKind = e.kind;

    widget.onStart?.call();

    if (widget.getHintText != null) {
      final hintText = widget.getHintText!();
      if (hintText.isNotEmpty) {
        changeHintId = HintStore.instance.addHint([
          HintSection('click + drag', hintText),
        ]);
      }
    }

    final mediaQuery = MediaQuery.of(context);
    devicePixelRatio = mediaQuery.devicePixelRatio;

    final windowPos = await getWindowPosition();
    final windowSize = await getWindowSize();
    if (!mounted) {
      return;
    }

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
  }

  void onPointerMove(PointerLockMoveEvent e) {
    if (pointerDeviceKind == null) return;

    accumulatorX += e.delta.dx;
    accumulatorY += e.delta.dy;
    _activeClickMoved = _activeClickMoved || e.delta.dx != 0 || e.delta.dy != 0;

    widget.onChange?.call(
      ControlMouseEvent(
        delta: Offset(e.delta.dx, -e.delta.dy),
        absolute: Offset(accumulatorX, -accumulatorY),
        kind: pointerDeviceKind!,
        isScroll: false,
      ),
    );

    if (widget.getHintText != null && changeHintId != null) {
      HintStore.instance.updateHint(changeHintId!, [
        HintSection('click + drag', widget.getHintText!()),
      ]);
    }
  }

  void onPointerUp(PointerEvent e) {
    if (pointerDeviceKind == null) {
      _recordActiveClick();
      return;
    }

    widget.onEnd?.call(
      ControlMouseEvent(
        delta: const Offset(0, 0),
        absolute: Offset(accumulatorX, accumulatorY),
        kind: pointerDeviceKind!,
        isScroll: false,
      ),
    );

    _recordActiveClick();

    accumulatorX = 0;
    accumulatorY = 0;
    pointerDeviceKind = null;

    if (changeHintId != null) {
      HintStore.instance.removeHint(changeHintId!);
      changeHintId = null;
    }
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
        kind: e.kind,
        isScroll: true,
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
      onPointerSignal: onPointerSignal,
      child: widget.child,
    );

    final lock = PointerLockDragArea(
      windowsMode: PointerLockWindowsMode.capture,
      accept: _acceptPointerLock,
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

    return MouseRegion(
      cursor: widget.cursor,
      child: lock,
      onEnter: (e) {
        if (baseHintId != null) {
          HintStore.instance.removeHint(baseHintId!);
          baseHintId = null;
        }

        if (widget.baseHint != null) {
          baseHintId = HintStore.instance.addHint([
            HintSection('click + drag', widget.baseHint!),
          ]);
        }
      },
      onExit: (e) {
        if (changeHintId != null) {
          return;
        }

        if (baseHintId != null) {
          HintStore.instance.removeHint(baseHintId!);
          baseHintId = null;
        }
      },
    );
  }
}
