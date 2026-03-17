/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'dart:collection';
import 'dart:math' as math;

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'helpers/time_helpers.dart';
import 'helpers/types.dart';

// Scales raw wheel deltas before they feed the 1D wheel-scroll path.
const _mouseWheelDeltaMultiplier = 1.0;

// Scales raw vertical trackpad deltas before they enter pan/zoom handling.
const _trackpadVerticalDeltaMultiplier = 1.0;

// On web, pan/zoom gestures arrive as scroll events, so we reset the
// gesture state after a short period of inactivity.
const _panZoomGestureIdleResetDelay = Duration(milliseconds: 96);

// Scales wheel input for the timeline strip's zoom-only interaction model.
const _timelineWheelZoomMultiplier = 1.5;

// Scales trackpad vertical pan deltas for the timeline strip's zoom-only
// interaction model.
const _timelineTrackpadZoomMultiplier = 0.7;

/// Abstracts scroll and zoom events for editors.
///
/// This widget is meant to be rendered around an editor canvas. It intercepts
/// mouse events related to scrolling (e.g. middle-mouse click + drag) and
/// handles them appropriately.
///
/// For horizontal scroll and zoom, this widget has a [TimeRange] property that
/// it directly manipulates. We encode time in the same way across all editors,
/// and since [TimeRange] is a MobX object, we can just mutate it directly from
/// this widget.
///
/// Vertical scrolling means different things to different editors (tracks for
/// the arranger, notes for the piano roll, etc.), so for vertical scroll, we
/// allow consumers to provide event handlers to this widget to monitor and
/// react to changes.
class EditorScrollManager extends StatefulWidget {
  final Widget? child;
  final TimeRange? timeView;
  final _EditorScrollManagerMode _mode;

  /// Applies a vertical scroll delta and returns the amount that was actually
  /// consumed after any clamping.
  final double Function(double delta)? onVerticalScrollChange;

  final void Function(double pointerY)? onVerticalPanStart;
  final void Function(double pointerY)? onVerticalPanMove;

  final void Function(double pointerY, double delta)? onVerticalZoom;

  /// Creates a scroll surface for timeline-based editor canvases.
  ///
  /// Horizontal motion and zoom are mapped onto [timeView], while vertical
  /// movement is delegated to the supplied callbacks.
  const EditorScrollManager.editor({
    super.key,
    this.child,
    required TimeRange this.timeView,
    this.onVerticalScrollChange,
    this.onVerticalPanStart,
    this.onVerticalPanMove,
    this.onVerticalZoom,
  }) : _mode = _EditorScrollManagerMode.editor;

  /// Creates a scroll surface for timeline strips that zoom horizontally in
  /// response to wheel and trackpad input.
  ///
  /// Unlike editor canvases, the timeline does not treat wheel input as
  /// vertical scrolling. Instead, vertical pointer deltas zoom [timeView]
  /// around the current pointer position.
  const EditorScrollManager.timeline({
    super.key,
    this.child,
    required TimeRange this.timeView,
  }) : onVerticalScrollChange = null,
       onVerticalPanStart = null,
       onVerticalPanMove = null,
       onVerticalZoom = null,
       _mode = _EditorScrollManagerMode.timeline;

  /// Creates a scroll surface for regions that should only respond to vertical
  /// scrolling and vertical zoom gestures.
  ///
  /// This is intended for surfaces like arranger track headers which should
  /// feel identical to the main editor when scrolling, but should not allow
  /// horizontal timeline motion.
  const EditorScrollManager.verticalOnly({
    super.key,
    this.child,
    this.onVerticalScrollChange,
    this.onVerticalZoom,
  }) : timeView = null,
       onVerticalPanStart = null,
       onVerticalPanMove = null,
       _mode = _EditorScrollManagerMode.verticalOnly;

  @override
  State<EditorScrollManager> createState() => _EditorScrollManagerState();
}

class _EditorScrollManagerState extends State<EditorScrollManager>
    with TickerProviderStateMixin {
  TimeRange get _timeView {
    final timeView = widget.timeView;
    if (timeView == null) {
      throw StateError(
        'EditorScrollManager.editor and EditorScrollManager.timeline must provide a TimeRange.',
      );
    }

    return timeView;
  }

  double _panInitialTimeViewStart = double.nan;
  double _panInitialTimeViewEnd = double.nan;
  double _panInitialX = double.nan;

  late final _ScrollAxisController _horizontalAxisController;
  late final _ScrollAxisController _verticalAxisController;
  final PanZoomAxisCoordinator _panZoomAxisCoordinator =
      PanZoomAxisCoordinator();

  Timer? _panZoomGestureResetTimer;
  bool _isPanZoomGestureActive = false;

  bool get _supportsHorizontalScroll =>
      widget._mode == _EditorScrollManagerMode.editor;

  bool get _supportsHorizontalZoom => widget.timeView != null;

  bool get _supportsMiddleMousePan =>
      widget._mode == _EditorScrollManagerMode.editor;

  bool get _usesTimelineZoomOnlyInput =>
      widget._mode == _EditorScrollManagerMode.timeline;

  bool get _hasVerticalInputHandler =>
      widget.onVerticalScrollChange != null || widget.onVerticalZoom != null;

  @override
  void initState() {
    super.initState();

    _horizontalAxisController = _ScrollAxisController(
      vsync: this,
      isEnabled: () => _supportsHorizontalScroll,
      applyDelta: (delta) =>
          _supportsHorizontalScroll ? _applyHorizontalScrollDelta(delta) : 0,
    );

    _verticalAxisController = _ScrollAxisController(
      vsync: this,
      isEnabled: () => widget.onVerticalScrollChange != null,
      applyDelta: (delta) => widget.onVerticalScrollChange?.call(delta) ?? 0,
    );
  }

  @override
  void dispose() {
    _panZoomGestureResetTimer?.cancel();
    _horizontalAxisController.dispose();
    _verticalAxisController.dispose();
    super.dispose();
  }

  double _applyHorizontalScrollDelta(double delta) {
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final viewWidth = contentRenderBox.size.width;
    if (viewWidth <= 0) {
      return 0;
    }

    final timeView = _timeView;
    final originalStart = timeView.start;
    final originalEnd = timeView.end;

    final ticksPerPixel = timeView.width / viewWidth;
    var scrollAmountInTicks = delta * ticksPerPixel;

    if (originalStart + scrollAmountInTicks < 0) {
      scrollAmountInTicks = -originalStart;
    }

    timeView.start = originalStart + scrollAmountInTicks;
    timeView.end = originalEnd + scrollAmountInTicks;

    final appliedTicks = timeView.start - originalStart;
    if (ticksPerPixel == 0) {
      return 0;
    }

    return appliedTicks / ticksPerPixel;
  }

  void _handleHorizontalZoom(double pointerX, double delta) {
    final contentRenderBox = context.findRenderObject() as RenderBox;

    zoomTimeView(
      timeView: _timeView,
      delta: delta,
      mouseX: pointerX,
      editorWidth: contentRenderBox.size.width,
    );
  }

  void _handleMiddlePointerDown(Offset pointerPos) {
    final timeView = _timeView;
    _panInitialTimeViewStart = timeView.start;
    _panInitialTimeViewEnd = timeView.end;
    _panInitialX = pointerPos.dx;

    widget.onVerticalPanStart?.call(pointerPos.dy);
  }

  void _handleMiddlePointerMove(Offset pointerPos, Size viewSize) {
    final timeView = _timeView;
    final deltaX = pointerPos.dx - _panInitialX;
    final deltaTimeSincePanInit = (-deltaX / viewSize.width) * timeView.width;

    var start = _panInitialTimeViewStart + deltaTimeSincePanInit;
    var end = _panInitialTimeViewEnd + deltaTimeSincePanInit;

    if (start < 0) {
      final delta = -start;
      start += delta;
      end += delta;
    }

    timeView.start = start;
    timeView.end = end;

    widget.onVerticalPanMove?.call(pointerPos.dy);
  }

  void _stopAllAxisActivity({required bool clearSamples}) {
    _horizontalAxisController.stop(clearSamples: clearSamples);
    _verticalAxisController.stop(clearSamples: clearSamples);
  }

  void _beginPanZoomGesture() {
    _panZoomGestureResetTimer?.cancel();

    if (!_isPanZoomGestureActive) {
      _isPanZoomGestureActive = true;
      _panZoomAxisCoordinator.reset();
    }
  }

  void _schedulePanZoomGestureReset() {
    _panZoomGestureResetTimer?.cancel();
    _panZoomGestureResetTimer = Timer(
      _panZoomGestureIdleResetDelay,
      _endPanZoomGesture,
    );
  }

  void _endPanZoomGesture({bool startFling = false}) {
    _panZoomGestureResetTimer?.cancel();
    _panZoomGestureResetTimer = null;

    if (startFling) {
      _horizontalAxisController.startFling();
      _verticalAxisController.startFling();
    }

    _isPanZoomGestureActive = false;
    _panZoomAxisCoordinator.reset();
  }

  void _handleScroll(PointerScrollEvent event) {
    if (_usesTimelineZoomOnlyInput) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);

      final contentRenderBox = context.findRenderObject() as RenderBox;
      final pointerPos = contentRenderBox.globalToLocal(event.position);
      _handleHorizontalZoom(
        pointerPos.dx,
        event.scrollDelta.dy * _timelineWheelZoomMultiplier,
      );
      return;
    }

    var delta = event.scrollDelta.dy;

    if (event.kind == PointerDeviceKind.mouse) {
      delta *= _mouseWheelDeltaMultiplier;
    }

    final modifiers = Provider.of<KeyboardModifiers>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(event.position);

    if (modifiers.ctrl) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);

      if (_supportsHorizontalZoom) {
        _handleHorizontalZoom(pointerPos.dx, delta);
      }
      return;
    }

    if (modifiers.alt) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);

      widget.onVerticalZoom?.call(pointerPos.dy, -delta * 0.005);
      return;
    }

    if (modifiers.shift) {
      _endPanZoomGesture();
      _verticalAxisController.stop(clearSamples: true);
      _horizontalAxisController.applyUserDelta(delta, event.timeStamp);
      return;
    }

    _endPanZoomGesture();
    _horizontalAxisController.stop(clearSamples: true);
    _verticalAxisController.applyUserDelta(delta, event.timeStamp);
  }

  void _handlePanZoomUpdate(PointerEvent event) {
    _beginPanZoomGesture();
    _schedulePanZoomGestureReset();

    final panZoomEvent = event is PointerPanZoomUpdateEvent ? event : null;
    final scrollEvent = event is PointerScrollEvent ? event : null;

    final dx = panZoomEvent?.localPanDelta.dx ?? -scrollEvent!.scrollDelta.dx;
    final dy = panZoomEvent?.localPanDelta.dy ?? -scrollEvent!.scrollDelta.dy;

    if ((panZoomEvent?.scale ?? 1) != 1) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);
      return;
    }

    final modifiers = Provider.of<KeyboardModifiers>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(event.position);

    if (_usesTimelineZoomOnlyInput) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);
      _handleHorizontalZoom(
        pointerPos.dx,
        -dy * _timelineTrackpadZoomMultiplier,
      );
      return;
    }

    if (modifiers.ctrl) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);

      if (_supportsHorizontalZoom) {
        _handleHorizontalZoom(pointerPos.dx, -dy * 0.8);
      }
      return;
    }

    if (modifiers.alt) {
      _endPanZoomGesture();
      _stopAllAxisActivity(clearSamples: true);

      widget.onVerticalZoom?.call(pointerPos.dy, -dy * 0.01);
      return;
    }

    final filteredDelta = switch ((
      _supportsHorizontalScroll,
      _hasVerticalInputHandler,
    )) {
      (true, true) => _panZoomAxisCoordinator.filter(
        dx: -dx,
        dy: -dy * _trackpadVerticalDeltaMultiplier,
      ),
      (true, false) => (dx: -dx, dy: 0.0),
      (false, true) => (dx: 0.0, dy: -dy * _trackpadVerticalDeltaMultiplier),
      (false, false) => (dx: 0.0, dy: 0.0),
    };

    _horizontalAxisController.applyUserDelta(filteredDelta.dx, event.timeStamp);
    _verticalAxisController.applyUserDelta(filteredDelta.dy, event.timeStamp);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        // Special case for web. See https://github.com/flutter/flutter/issues/174251
        if (kIsWeb) {
          if (event is PointerScrollEvent) {
            _handlePanZoomUpdate(event);
          }
          return;
        }

        if (event is PointerScrollEvent) {
          _handleScroll(event);
        }
      },
      onPointerPanZoomStart: (_) {
        _beginPanZoomGesture();
      },
      onPointerPanZoomUpdate: _handlePanZoomUpdate,
      onPointerPanZoomEnd: (_) {
        _endPanZoomGesture(startFling: true);
      },
      onPointerDown: (event) {
        _endPanZoomGesture();
        _stopAllAxisActivity(clearSamples: true);

        if (_supportsMiddleMousePan &&
            event.buttons & kMiddleMouseButton == kMiddleMouseButton) {
          final contentRenderBox = context.findRenderObject() as RenderBox;
          final pointerPos = contentRenderBox.globalToLocal(event.position);
          _handleMiddlePointerDown(pointerPos);
        }
      },
      onPointerMove: (event) {
        if (_supportsMiddleMousePan &&
            event.buttons & kMiddleMouseButton == kMiddleMouseButton) {
          final contentRenderBox = context.findRenderObject() as RenderBox;
          final pointerPos = contentRenderBox.globalToLocal(event.position);
          _handleMiddlePointerMove(pointerPos, contentRenderBox.size);
        }
      },
      child: widget.child,
    );
  }
}

enum _EditorScrollManagerMode { editor, timeline, verticalOnly }

/// Manages scrolling behavior for a single logical axis.
///
/// This helper owns immediate delta application, recent input sampling, fling
/// scheduling, and ballistic simulation. The caller supplies an [applyDelta]
/// callback that mutates the real editor state and reports how much movement
/// was actually consumed after clamping.
class _ScrollAxisController {
  // Wait this long after the last user delta before converting the recent
  // input history into a fling.
  static const _flingStartDelay = Duration(milliseconds: 72);

  // Keep only this much recent delta history when estimating fling velocity.
  static const _velocitySampleWindow = Duration(milliseconds: 120);

  // Ignore tiny residual velocities so short or hesitant gestures stop
  // immediately instead of coasting.
  static const _minimumFlingVelocity = 160.0;

  // Additional damping applied to the estimated velocity before creating the
  // ballistic simulation.
  static const _flingVelocityFactor = 0.6;

  // Treat controller changes smaller than this as noise to avoid feedback
  // loops while syncing simulated and applied positions.
  static const _controllerValueEpsilon = 1e-6;

  final double Function(double delta) applyDelta;
  final bool Function()? isEnabled;

  late final AnimationController _controller;
  final ListQueue<_ScrollDeltaSample> _deltaSamples = ListQueue();

  Timer? _flingTimer;
  double _lastControllerValue = 0;
  bool _isSyncingControllerValue = false;

  _ScrollAxisController({
    required TickerProvider vsync,
    required this.applyDelta,
    this.isEnabled,
  }) {
    _controller = AnimationController.unbounded(vsync: vsync)
      ..addListener(_handleAnimationTick);
  }

  bool get _isActive => isEnabled?.call() ?? true;

  void dispose() {
    _flingTimer?.cancel();
    _controller.dispose();
  }

  void applyUserDelta(double delta, Duration timeStamp) {
    if (!_isActive || delta.abs() <= _controllerValueEpsilon) {
      return;
    }

    stop(clearSamples: false);
    _recordScrollDelta(delta: delta, timeStamp: timeStamp);
    _controller.value += delta;
    _scheduleFling();
  }

  void startFling() {
    _flingTimer?.cancel();
    _flingTimer = null;

    if (!_isActive) {
      _deltaSamples.clear();
      return;
    }

    final velocity = _estimateVelocity();
    if (velocity.abs() < _minimumFlingVelocity) {
      _deltaSamples.clear();
      return;
    }

    _controller.animateWith(
      ClampingScrollSimulation(
        position: _controller.value,
        velocity: velocity * _flingVelocityFactor,
      ),
    );
    _deltaSamples.clear();
  }

  void stop({required bool clearSamples}) {
    _flingTimer?.cancel();
    _flingTimer = null;
    _controller.stop();

    if (clearSamples) {
      _deltaSamples.clear();
    }
  }

  void _scheduleFling() {
    _flingTimer?.cancel();
    _flingTimer = Timer(_flingStartDelay, startFling);
  }

  void _handleAnimationTick() {
    if (_isSyncingControllerValue) {
      return;
    }

    final delta = _controller.value - _lastControllerValue;
    if (delta.abs() <= _controllerValueEpsilon) {
      return;
    }

    final appliedDelta = _isActive ? applyDelta(delta) : 0.0;
    _syncControllerValue(_lastControllerValue + appliedDelta);
  }

  void _syncControllerValue(double targetValue) {
    if (_isSyncingControllerValue) {
      return;
    }

    _isSyncingControllerValue = true;

    if ((_controller.value - targetValue).abs() > _controllerValueEpsilon) {
      _controller
        ..stop()
        ..value = targetValue;
    }

    _lastControllerValue = _controller.value;
    _isSyncingControllerValue = false;
  }

  void _recordScrollDelta({
    required double delta,
    required Duration timeStamp,
  }) {
    final cutoff = timeStamp - _velocitySampleWindow;
    while (_deltaSamples.isNotEmpty && _deltaSamples.first.timeStamp < cutoff) {
      _deltaSamples.removeFirst();
    }

    _deltaSamples.addLast(
      _ScrollDeltaSample(timeStamp: timeStamp, delta: delta),
    );
  }

  double _estimateVelocity() {
    if (_deltaSamples.length < 2) {
      return 0;
    }

    final elapsedMicros =
        _deltaSamples.last.timeStamp.inMicroseconds -
        _deltaSamples.first.timeStamp.inMicroseconds;
    if (elapsedMicros <= 0) {
      return 0;
    }

    final totalDelta = _deltaSamples.fold<double>(
      0,
      (sum, sample) => sum + sample.delta,
    );

    return totalDelta / (elapsedMicros / Duration.microsecondsPerSecond);
  }
}

/// Interprets 2D pan gestures and decides whether they should remain free on
/// both axes or lock to a dominant axis.
///
/// Each gesture begins in an undecided state. As travel accumulates, the
/// coordinator transitions to horizontal lock, vertical lock, or free movement
/// based on gesture shape, and later uses hysteresis thresholds to unlock or
/// switch axes.
@visibleForTesting
class PanZoomAxisCoordinator {
  // Total gesture travel required before we commit to a lock mode instead of
  // continuing to treat the gesture as undecided.
  static const _decisionDistance = 18.0;

  // Minimum travel each axis must contribute before a gesture can be treated
  // as genuinely diagonal and therefore unlocked.
  static const _diagonalMinimumComponentDistance = 8.0;

  // If one axis exceeds the other by at least this ratio during the undecided
  // phase, we lock to the dominant axis.
  static const _lockDominanceRatio = 1.75;

  // If the dominant axis stays within this ratio of the secondary axis, we
  // consider the gesture diagonal enough to keep both axes active.
  static const _freeDiagonalRatio = 1.35;

  // While locked, require at least this much suppressed travel on the other
  // axis before considering an unlock or axis switch.
  static const _unlockDistance = 54.0;

  // After the unlock distance is met, the opposing axis must exceed the active
  // one by at least this ratio to switch locks directly.
  static const _switchDominanceRatio = 1.2;

  // Small-value guard used to avoid divide-by-near-zero cases in ratio checks.
  static const _deltaEpsilon = 1e-6;

  PanZoomAxisLockMode _mode = PanZoomAxisLockMode.undecided;

  @visibleForTesting
  PanZoomAxisLockMode get mode => _mode;

  double _accumulatedHorizontalTravel = 0;
  double _accumulatedVerticalTravel = 0;
  double _suppressedHorizontalTravelSinceLock = 0;
  double _suppressedVerticalTravelSinceLock = 0;

  void reset() {
    _mode = PanZoomAxisLockMode.undecided;
    _accumulatedHorizontalTravel = 0;
    _accumulatedVerticalTravel = 0;
    _suppressedHorizontalTravelSinceLock = 0;
    _suppressedVerticalTravelSinceLock = 0;
  }

  ({double dx, double dy}) filter({required double dx, required double dy}) {
    _accumulatedHorizontalTravel += dx.abs();
    _accumulatedVerticalTravel += dy.abs();

    switch (_mode) {
      case PanZoomAxisLockMode.undecided:
        _maybeResolveInitialMode();
        return _filteredDeltaForCurrentMode(dx: dx, dy: dy);
      case PanZoomAxisLockMode.free:
        return (dx: dx, dy: dy);
      case PanZoomAxisLockMode.lockedHorizontal:
        _suppressedVerticalTravelSinceLock += dy.abs();
        _maybeTransitionOutOfLockedHorizontal(dx: dx, dy: dy);
        return _filteredDeltaForCurrentMode(dx: dx, dy: dy);
      case PanZoomAxisLockMode.lockedVertical:
        _suppressedHorizontalTravelSinceLock += dx.abs();
        _maybeTransitionOutOfLockedVertical(dx: dx, dy: dy);
        return _filteredDeltaForCurrentMode(dx: dx, dy: dy);
    }
  }

  void _maybeResolveInitialMode() {
    final totalTravel =
        _accumulatedHorizontalTravel + _accumulatedVerticalTravel;
    if (totalTravel < _decisionDistance) {
      return;
    }

    final dominantTravel = math.max(
      _accumulatedHorizontalTravel,
      _accumulatedVerticalTravel,
    );
    final secondaryTravel = math.min(
      _accumulatedHorizontalTravel,
      _accumulatedVerticalTravel,
    );
    final dominanceRatio = secondaryTravel <= _deltaEpsilon
        ? double.infinity
        : dominantTravel / secondaryTravel;

    if (secondaryTravel >= _diagonalMinimumComponentDistance &&
        dominanceRatio <= _freeDiagonalRatio) {
      _mode = PanZoomAxisLockMode.free;
      return;
    }

    if (_accumulatedHorizontalTravel >=
        _accumulatedVerticalTravel * _lockDominanceRatio) {
      _lockHorizontal();
      return;
    }

    if (_accumulatedVerticalTravel >=
        _accumulatedHorizontalTravel * _lockDominanceRatio) {
      _lockVertical();
      return;
    }

    if (secondaryTravel >= _diagonalMinimumComponentDistance) {
      _mode = PanZoomAxisLockMode.free;
    }
  }

  void _maybeTransitionOutOfLockedHorizontal({
    required double dx,
    required double dy,
  }) {
    if (_suppressedVerticalTravelSinceLock < _unlockDistance) {
      return;
    }

    final horizontalMagnitude = dx.abs();
    final verticalMagnitude = dy.abs();

    if (verticalMagnitude > horizontalMagnitude * _switchDominanceRatio) {
      _lockVertical();
      return;
    }

    if (_isDiagonalEvent(
      horizontalMagnitude: horizontalMagnitude,
      verticalMagnitude: verticalMagnitude,
    )) {
      _mode = PanZoomAxisLockMode.free;
    }
  }

  void _maybeTransitionOutOfLockedVertical({
    required double dx,
    required double dy,
  }) {
    if (_suppressedHorizontalTravelSinceLock < _unlockDistance) {
      return;
    }

    final horizontalMagnitude = dx.abs();
    final verticalMagnitude = dy.abs();

    if (horizontalMagnitude > verticalMagnitude * _switchDominanceRatio) {
      _lockHorizontal();
      return;
    }

    if (_isDiagonalEvent(
      horizontalMagnitude: horizontalMagnitude,
      verticalMagnitude: verticalMagnitude,
    )) {
      _mode = PanZoomAxisLockMode.free;
    }
  }

  bool _isDiagonalEvent({
    required double horizontalMagnitude,
    required double verticalMagnitude,
  }) {
    if (horizontalMagnitude < _diagonalMinimumComponentDistance ||
        verticalMagnitude < _diagonalMinimumComponentDistance) {
      return false;
    }

    final dominantMagnitude = math.max(horizontalMagnitude, verticalMagnitude);
    final secondaryMagnitude = math.min(horizontalMagnitude, verticalMagnitude);
    if (secondaryMagnitude <= _deltaEpsilon) {
      return false;
    }

    return dominantMagnitude / secondaryMagnitude <= _freeDiagonalRatio;
  }

  ({double dx, double dy}) _filteredDeltaForCurrentMode({
    required double dx,
    required double dy,
  }) {
    return switch (_mode) {
      PanZoomAxisLockMode.undecided ||
      PanZoomAxisLockMode.free => (dx: dx, dy: dy),
      PanZoomAxisLockMode.lockedHorizontal => (dx: dx, dy: 0.0),
      PanZoomAxisLockMode.lockedVertical => (dx: 0.0, dy: dy),
    };
  }

  void _lockHorizontal() {
    _mode = PanZoomAxisLockMode.lockedHorizontal;
    _suppressedHorizontalTravelSinceLock = 0;
    _suppressedVerticalTravelSinceLock = 0;
  }

  void _lockVertical() {
    _mode = PanZoomAxisLockMode.lockedVertical;
    _suppressedHorizontalTravelSinceLock = 0;
    _suppressedVerticalTravelSinceLock = 0;
  }
}

/// The current interpretation of a pan gesture with respect to axis locking.
@visibleForTesting
enum PanZoomAxisLockMode { undecided, free, lockedHorizontal, lockedVertical }

/// Timestamped delta sample used to estimate fling velocity from recent input.
class _ScrollDeltaSample {
  final Duration timeStamp;
  final double delta;

  const _ScrollDeltaSample({required this.timeStamp, required this.delta});
}
