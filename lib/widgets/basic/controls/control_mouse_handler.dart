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
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:pointer_lock/pointer_lock.dart';

const _doubleClickThreshold = Duration(milliseconds: 500);
const _maxDoubleClickDistance = 8.0;
const _pointerLockWindowsMode = PointerLockWindowsMode.capture;
const _initialPointerLockMoveLogCount = 5;
const _pointerLockMoveLogInterval = 50;

final _pointerLockLog = Logger(
  'ui.controls.control_mouse_handler.pointer_lock',
);

int _nextControlMouseHandlerId = 1;
int _nextPointerLockSessionId = 1;

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
  final int _handlerId = _nextControlMouseHandlerId++;

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

  int? _activePointerLockSessionId;
  DateTime? _activePointerLockSessionStartedAt;
  bool _activePointerLockMetricsReady = false;
  bool _loggedMoveBeforeMetrics = false;
  int _pointerLockMoveCount = 0;
  int _pointerLockNonZeroMoveCount = 0;
  Offset _pointerLockTotalRawDelta = Offset.zero;

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
    final reportsPointerUpDownEventsReliably = pointerLock
        .reportsPointerUpDownEventsReliably(
          windowsMode: _pointerLockWindowsMode,
        );

    _pointerLockLog.info(
      'Checking pointer lock accept. '
      'handler=$_handlerId, '
      'event=${_describePointerEvent(event)}, '
      'targetPlatform=$defaultTargetPlatform, '
      'kIsWeb=$kIsWeb, '
      'windowsMode=$_pointerLockWindowsMode, '
      'reportsPointerUpDownEventsReliably=$reportsPointerUpDownEventsReliably, '
      'unlockOnPointerUp=${!reportsPointerUpDownEventsReliably}',
    );

    if (!_isPrimaryButton(event)) {
      _pointerLockLog.info(
        'Rejected pointer lock because the primary button is not pressed. '
        'handler=$_handlerId, event=${_describePointerEvent(event)}',
      );
      _clearPendingClick();
      _clearActiveClick();
      return false;
    }

    if (_qualifiesAsDoubleClick(event)) {
      _pointerLockLog.info(
        'Rejected pointer lock because the event is a double click. '
        'handler=$_handlerId, event=${_describePointerEvent(event)}',
      );
      _clearPendingClick();
      _clearActiveClick();
      widget.onDoubleClick?.call();
      return false;
    }

    _activeClickTimestamp = event.timeStamp;
    _activeClickPosition = event.position;
    _activeClickMoved = false;

    _pointerLockLog.info(
      'Accepted pointer lock. '
      'handler=$_handlerId, event=${_describePointerEvent(event)}',
    );

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

  void _beginPointerLockSession(PointerDownEvent trigger) {
    final existingSessionId = _activePointerLockSessionId;
    if (existingSessionId != null) {
      _pointerLockLog.warning(
        'Starting a pointer lock session while another session is active. '
        'handler=$_handlerId, existingSession=$existingSessionId, '
        'trigger=${_describePointerEvent(trigger)}',
      );
    }

    final reportsPointerUpDownEventsReliably = pointerLock
        .reportsPointerUpDownEventsReliably(
          windowsMode: _pointerLockWindowsMode,
        );

    _activePointerLockSessionId = _nextPointerLockSessionId++;
    _activePointerLockSessionStartedAt = DateTime.now();
    _activePointerLockMetricsReady = false;
    _loggedMoveBeforeMetrics = false;
    _pointerLockMoveCount = 0;
    _pointerLockNonZeroMoveCount = 0;
    _pointerLockTotalRawDelta = Offset.zero;

    _pointerLockLog.info(
      'PointerLockDragArea emitted onLock. '
      'handler=$_handlerId, '
      'session=$_activePointerLockSessionId, '
      'trigger=${_describePointerEvent(trigger)}, '
      'cursor=${PointerLockCursor.hidden}, '
      'windowsMode=$_pointerLockWindowsMode, '
      'targetPlatform=$defaultTargetPlatform, '
      'kIsWeb=$kIsWeb, '
      'reportsPointerUpDownEventsReliably=$reportsPointerUpDownEventsReliably, '
      'unlockOnPointerUp=${!reportsPointerUpDownEventsReliably}',
    );
  }

  void _recordPointerLockMove(PointerLockMoveEvent event, Offset controlDelta) {
    final sessionId = _activePointerLockSessionId;
    _pointerLockMoveCount++;
    _pointerLockTotalRawDelta += event.delta;

    if (event.delta.dx != 0 || event.delta.dy != 0) {
      _pointerLockNonZeroMoveCount++;
    }

    if (!_activePointerLockMetricsReady && !_loggedMoveBeforeMetrics) {
      _loggedMoveBeforeMetrics = true;
      _pointerLockLog.warning(
        'Received pointer lock move before window metrics were ready. '
        'handler=$_handlerId, session=$sessionId, '
        'move=$_pointerLockMoveCount, rawDelta=${_formatOffset(event.delta)}',
      );
    }

    if (_pointerLockMoveCount <= _initialPointerLockMoveLogCount ||
        _pointerLockMoveCount % _pointerLockMoveLogInterval == 0) {
      _pointerLockLog.fine(
        'Pointer lock move. '
        'handler=$_handlerId, '
        'session=$sessionId, '
        'move=$_pointerLockMoveCount, '
        'nonZeroMoves=$_pointerLockNonZeroMoveCount, '
        'rawDelta=${_formatOffset(event.delta)}, '
        'controlDelta=${_formatOffset(controlDelta)}, '
        'rawTotal=${_formatOffset(_pointerLockTotalRawDelta)}, '
        'controlAbsolute=${_formatOffset(Offset(accumulatorX, -accumulatorY))}, '
        'metricsReady=$_activePointerLockMetricsReady',
      );
    }
  }

  void _finishPointerLockSession(PointerEvent trigger) {
    final sessionId = _activePointerLockSessionId;
    if (sessionId == null) {
      _pointerLockLog.warning(
        'PointerLockDragArea emitted onUnlock with no active session. '
        'handler=$_handlerId, trigger=${_describePointerEvent(trigger)}',
      );
      return;
    }

    final startedAt = _activePointerLockSessionStartedAt;
    final durationMs = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inMilliseconds;

    _pointerLockLog.info(
      'PointerLockDragArea emitted onUnlock. '
      'handler=$_handlerId, '
      'session=$sessionId, '
      'durationMs=$durationMs, '
      'moves=$_pointerLockMoveCount, '
      'nonZeroMoves=$_pointerLockNonZeroMoveCount, '
      'rawTotal=${_formatOffset(_pointerLockTotalRawDelta)}, '
      'controlAbsolute=${_formatOffset(Offset(accumulatorX, -accumulatorY))}, '
      'metricsReady=$_activePointerLockMetricsReady, '
      'activeClickMoved=$_activeClickMoved, '
      'trigger=${_describePointerEvent(trigger)}',
    );

    _activePointerLockSessionId = null;
    _activePointerLockSessionStartedAt = null;
    _activePointerLockMetricsReady = false;
    _loggedMoveBeforeMetrics = false;
    _pointerLockMoveCount = 0;
    _pointerLockNonZeroMoveCount = 0;
    _pointerLockTotalRawDelta = Offset.zero;
  }

  String _describePointerEvent(PointerEvent event) {
    return 'pointer=${event.pointer}, '
        'kind=${event.kind.name}, '
        'buttons=${event.buttons}, '
        'position=${_formatOffset(event.position)}, '
        'localPosition=${_formatOffset(event.localPosition)}, '
        'timeStampMs=${event.timeStamp.inMilliseconds}';
  }

  String _formatOffset(Offset offset) {
    return '(${offset.dx.toStringAsFixed(3)}, '
        '${offset.dy.toStringAsFixed(3)})';
  }

  String _formatSize(Size size) {
    return '(${size.width.toStringAsFixed(3)}, '
        '${size.height.toStringAsFixed(3)})';
  }

  void onPointerDown(PointerEvent e) async {
    pointerDeviceKind = e.kind;

    _pointerLockLog.info(
      'Handling pointer lock trigger. '
      'handler=$_handlerId, '
      'session=$_activePointerLockSessionId, '
      'trigger=${_describePointerEvent(e)}',
    );

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

    late final Offset windowPos;
    late final Size windowSize;

    try {
      windowPos = await getWindowPosition();
      windowSize = await getWindowSize();
    } catch (error, stackTrace) {
      _pointerLockLog.severe(
        'Failed to read window metrics for pointer lock session. '
        'handler=$_handlerId, session=$_activePointerLockSessionId, '
        'devicePixelRatio=$devicePixelRatio',
        error,
        stackTrace,
      );
      rethrow;
    }

    if (!mounted) {
      _pointerLockLog.warning(
        'ControlMouseHandler unmounted while reading pointer lock metrics. '
        'handler=$_handlerId, session=$_activePointerLockSessionId',
      );
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
    _activePointerLockMetricsReady = true;

    _pointerLockLog.info(
      'Pointer lock window metrics ready. '
      'handler=$_handlerId, '
      'session=$_activePointerLockSessionId, '
      'devicePixelRatio=$devicePixelRatio, '
      'windowPosition=${_formatOffset(windowPos)}, '
      'windowSize=${_formatSize(windowSize)}, '
      'windowRect=$windowRect, '
      'triggerPosition=${_formatOffset(e.position)}, '
      'absoluteMouse=${_formatOffset(mousePos)}',
    );
  }

  void onPointerMove(PointerLockMoveEvent e) {
    if (pointerDeviceKind == null) {
      _pointerLockLog.warning(
        'Ignored pointer lock move because pointerDeviceKind is null. '
        'handler=$_handlerId, '
        'session=$_activePointerLockSessionId, '
        'rawDelta=${_formatOffset(e.delta)}',
      );
      return;
    }

    accumulatorX += e.delta.dx;
    accumulatorY += e.delta.dy;
    _activeClickMoved = _activeClickMoved || e.delta.dx != 0 || e.delta.dy != 0;
    final controlDelta = Offset(e.delta.dx, -e.delta.dy);

    _recordPointerLockMove(e, controlDelta);

    widget.onChange?.call(
      ControlMouseEvent(
        delta: controlDelta,
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
      _pointerLockLog.warning(
        'Handling pointer lock unlock with no pointerDeviceKind. '
        'handler=$_handlerId, '
        'session=$_activePointerLockSessionId, '
        'trigger=${_describePointerEvent(e)}',
      );
      _finishPointerLockSession(e);
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

    _finishPointerLockSession(e);
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
  void dispose() {
    final sessionId = _activePointerLockSessionId;
    if (sessionId != null) {
      _pointerLockLog.warning(
        'ControlMouseHandler disposed with an active pointer lock session. '
        'handler=$_handlerId, '
        'session=$sessionId, '
        'moves=$_pointerLockMoveCount, '
        'rawTotal=${_formatOffset(_pointerLockTotalRawDelta)}',
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listener = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: onPointerSignal,
      child: widget.child,
    );

    final lock = PointerLockDragArea(
      windowsMode: _pointerLockWindowsMode,
      accept: _acceptPointerLock,
      onLock: (e) {
        _beginPointerLockSession(e.trigger);
        onPointerDown(e.trigger);
      },
      onMove: (e) {
        onPointerMove(e.move);
      },
      onUnlock: (e) {
        onPointerUp(e.trigger);
        if (mounted) {
          setState(() {});
        }
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
