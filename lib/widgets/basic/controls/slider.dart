/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:math';

import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/lazy_follower.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'control_mouse_handler.dart';
import 'parameter_ui_binding.dart';
import 'sticky_drag_controller.dart';

export 'parameter_ui_binding.dart';

const _stickyTrapSize = 0.08;
const _directHandleHitThickness = 8.0;
const _doubleClickThreshold = Duration(milliseconds: 500);
const _maxDoubleClickDistance = 8.0;

class Slider extends StatefulWidget {
  final double? width;
  final double? height;
  final SliderAxis axis;
  final SliderType type;
  final double borderRadius;
  final bool noBackground;
  final bool usePointerLock;

  final double? value;
  final ParameterUiBinding? parameter;
  final double min;
  final double max;

  final void Function(double)? onValueChanged;
  final VoidCallback? onValueChangeStart;
  final void Function(double)? onValueChangeEnd;

  final List<double> stickyPoints;

  final String Function(double value)? hoverHintOverride;
  final String Function(double value)? hint;

  const Slider({
    super.key,
    this.width,
    this.height,
    this.axis = SliderAxis.horizontal,
    this.type = SliderType.normal,
    this.borderRadius = 1,
    this.noBackground = false,
    this.usePointerLock = true,
    this.value,
    this.parameter,
    this.onValueChanged,
    this.onValueChangeStart,
    this.onValueChangeEnd,
    this.max = 1,
    double? min,
    this.stickyPoints = const [],
    this.hoverHintOverride,
    this.hint,
  }) : min = min ?? (type == SliderType.pan ? -1 : 0),
       assert(value != null || parameter != null),
       assert(borderRadius >= 0);

  @override
  State<Slider> createState() => _SliderState();
}

class _SliderState extends State<Slider> with TickerProviderStateMixin {
  LazyFollowAnimationHelper? animationHelper;
  final StickyDragController dragController = StickyDragController(
    stickyTrapSize: _stickyTrapSize,
  );

  late final _SliderInputController pointerLockInputController;
  late final _SliderInputController directInputController;

  bool isOver = false;
  bool isPressed = false;

  double lastValue = -1;

  _SliderInputController get inputController {
    return widget.usePointerLock
        ? pointerLockInputController
        : directInputController;
  }

  @override
  void initState() {
    super.initState();

    pointerLockInputController = _PointerLockSliderInputController(this);
    directInputController = _DirectSliderInputController(this);
  }

  double scaledToRaw(double value) =>
      (value - widget.min) / (widget.max - widget.min);
  double rawToScaled(double rawValue) =>
      rawValue * (widget.max - widget.min) + widget.min;

  double currentValue([double? automationParameterValue]) {
    final parameter = widget.parameter;
    if (parameter == null) {
      return widget.value!;
    }

    if (automationParameterValue != null) {
      return parameter.uiValueForNormalizedParameterValue(
        automationParameterValue,
      );
    }

    return parameter.uiValue;
  }

  bool get canUpdateValue =>
      widget.parameter != null || widget.onValueChanged != null;

  MouseCursor get cursor => switch (widget.axis) {
    SliderAxis.horizontal => SystemMouseCursors.resizeLeftRight,
    SliderAxis.vertical => SystemMouseCursors.resizeUpDown,
  };

  void setHoverAnimationState(bool hover) {
    final [handleSizeHelper, _] = animationHelper!.items;
    handleSizeHelper.setTarget(hover ? 3 : 1);
  }

  void setPressAnimationState(bool pressed) {
    final [_, pressColorHelper] = animationHelper!.items;
    pressColorHelper.setTarget(pressed ? 1 : 0);
  }

  void startDrag(double value) {
    setState(() {
      isPressed = true;
    });

    lastValue = value;
    widget.parameter?.beginChange();
    widget.onValueChangeStart?.call();
    setHint(hover: false);

    setPressAnimationState(true);
    animationHelper!.update();
  }

  void endDrag() {
    setState(() {
      isPressed = false;
    });

    setPressAnimationState(false);

    if (!isOver) {
      setHoverAnimationState(false);
    }

    animationHelper!.update();
    widget.parameter?.commitChange();
    widget.onValueChangeEnd?.call(lastValue);
  }

  void resetDragController({required double rawValue}) {
    dragController.reset(
      rawValue: rawValue,
      stickyPoints: widget.stickyPoints
          .map(scaledToRaw)
          .toList(growable: false),
    );
  }

  void setRawValue(double rawValue) {
    if (!canUpdateValue) {
      return;
    }

    final clampedRawValue = rawValue.clamp(0.0, 1.0).toDouble();
    final newValue = rawToScaled(clampedRawValue);
    if (newValue == lastValue) {
      return;
    }

    widget.parameter?.updateChange(newValue);
    widget.onValueChanged?.call(newValue);
    lastValue = newValue;
  }

  void applyRawDelta(double rawDelta) {
    if (!canUpdateValue) {
      return;
    }

    final result = dragController.applyRawDelta(rawDelta);
    if (result.changed) {
      setRawValue(result.rawValue);
    }
  }

  void applyPixelDelta(Offset pixelDelta) {
    if (!canUpdateValue) {
      return;
    }

    final rawPixelChange = switch (widget.axis) {
      SliderAxis.horizontal => pixelDelta.dx,
      SliderAxis.vertical => pixelDelta.dy,
    };

    applyRawDelta(rawPixelChange / 300);
    setHint(hover: false);
  }

  double rawForLocalPosition({
    required Offset localPosition,
    required Size size,
  }) {
    return switch (widget.axis) {
      SliderAxis.horizontal when size.width > 0 =>
        localPosition.dx / size.width,
      SliderAxis.vertical when size.height > 0 =>
        1 - (localPosition.dy / size.height),
      _ => 0,
    };
  }

  bool isOverHandle({
    required Offset localPosition,
    required Size size,
    required double rawValue,
  }) {
    final clampedRawValue = rawValue.clamp(0.0, 1.0).toDouble();

    return switch (widget.axis) {
      SliderAxis.horizontal =>
        (localPosition.dx - size.width * clampedRawValue).abs() <=
            _directHandleHitThickness / 2,
      SliderAxis.vertical =>
        (localPosition.dy - size.height * (1 - clampedRawValue)).abs() <=
            _directHandleHitThickness / 2,
    };
  }

  int? currentHintId;

  void setHint({required bool hover}) {
    String? currentHintText;
    if (hover && widget.hoverHintOverride != null) {
      currentHintText = widget.hoverHintOverride!.call(lastValue);
    } else if (widget.hint != null) {
      currentHintText = widget.hint!.call(lastValue);
    }

    if (currentHintText == null) {
      clearHint();
      return;
    }

    if (currentHintId == null) {
      currentHintId = HintStore.instance.addHint([
        HintSection('click + drag', currentHintText),
      ]);
    } else {
      HintStore.instance.updateHint(currentHintId!, [
        HintSection('click + drag', currentHintText),
      ]);
    }
  }

  void clearHint() {
    if (currentHintId != null) {
      HintStore.instance.removeHint(currentHintId!);
      currentHintId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    animationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      items: [
        // Handle thickness
        LazyFollowItem(initialValue: 1),
        // Handle press color blend amount
        LazyFollowItem(initialValue: 0),
      ],
    );

    Widget buildControl({double? automationParameterValue}) {
      final value = currentValue(automationParameterValue);

      void resetParameterToDefault() {
        final parameter = widget.parameter;
        if (parameter == null) {
          return;
        }

        parameter.resetToDefault();
        lastValue = currentValue(automationParameterValue);
        setHint(hover: false);
      }

      final control = SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: animationHelper!.animationController,
          builder: (context, _) {
            final [handleSizeHelper, pressColorHelper] = animationHelper!.items;

            return CustomPaint(
              painter: _SliderPainter(
                value: scaledToRaw(value),
                axis: widget.axis,
                type: widget.type,
                handleThickness: handleSizeHelper.animation.value,
                handlePressAmount: pressColorHelper.animation.value,
                borderRadius: widget.borderRadius,
                noBackground: widget.noBackground,
              ),
            );
          },
        ),
      );

      return MouseRegion(
        cursor: cursor,
        onEnter: (e) {
          setState(() {
            isOver = true;
          });

          lastValue = value;
          setHint(hover: true);

          setHoverAnimationState(true);
          animationHelper!.update();
        },
        onExit: (e) {
          setState(() {
            isOver = false;
          });

          clearHint();

          if (!isPressed) {
            setHoverAnimationState(false);
            animationHelper!.update();
          }
        },
        child: inputController.build(
          child: control,
          value: value,
          onDoubleClick: widget.parameter == null
              ? null
              : resetParameterToDefault,
        ),
      );
    }

    if (widget.parameter == null) {
      return buildControl();
    }

    return Observer(
      builder: (_) {
        final automationVisualizationId =
            widget.parameter!.automationVisualizationId;
        if (automationVisualizationId == null) {
          return buildControl();
        }

        return VisualizationBuilder.double(
          config: VisualizationSubscriptionConfig.latestDouble(
            automationVisualizationId,
          ),
          builder: (context, value, engineTime) {
            return Observer(
              warnWhenNoObservables: false,
              builder: (_) => buildControl(
                automationParameterValue: engineTime == null ? null : value,
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    clearHint();
    animationHelper?.dispose();
    super.dispose();
  }
}

abstract class _SliderInputController {
  Widget build({
    required Widget child,
    required double value,
    required VoidCallback? onDoubleClick,
  });
}

class _PointerLockSliderInputController implements _SliderInputController {
  final _SliderState state;

  const _PointerLockSliderInputController(this.state);

  @override
  Widget build({
    required Widget child,
    required double value,
    required VoidCallback? onDoubleClick,
  }) {
    return ControlMouseHandler(
      cursor: state.cursor,
      onDoubleClick: onDoubleClick,
      onStart: () {
        state.startDrag(value);
        state.resetDragController(rawValue: state.scaledToRaw(value));
      },
      onEnd: (_) {
        state.endDrag();
      },
      onChange: (event) {
        state.applyPixelDelta(event.delta);
      },
      child: child,
    );
  }
}

class _DirectSliderInputController implements _SliderInputController {
  final _SliderState state;
  final GlobalKey inputKey = GlobalKey();

  double storedOffsetRaw = 0;
  double lastTargetRaw = 0;
  int? activePointer;
  Offset activeClickPosition = Offset.zero;
  Duration activeClickTimestamp = Duration.zero;
  Offset mostRecentLocalPosition = Offset.zero;
  bool activeClickMoved = false;
  Duration? lastClickTimestamp;
  Offset? lastClickPosition;

  _DirectSliderInputController(this.state);

  @override
  Widget build({
    required Widget child,
    required double value,
    required VoidCallback? onDoubleClick,
  }) {
    return Listener(
      key: inputKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _onPointerDown(event, value, onDoubleClick);
      },
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerSignal: (event) {
        _onPointerSignal(event, value);
      },
      child: child,
    );
  }

  Size? get inputSize {
    final context = inputKey.currentContext;
    final renderObject = context?.findRenderObject();

    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }

    return null;
  }

  bool _isPrimaryButton(PointerDownEvent event) {
    return event.buttons & kPrimaryButton > 0;
  }

  bool _isWithinDoubleClickThreshold(Duration timestamp) {
    final lastClickTimestamp = this.lastClickTimestamp;
    if (lastClickTimestamp == null) {
      return false;
    }

    final elapsed = timestamp - lastClickTimestamp;
    return elapsed >= Duration.zero && elapsed <= _doubleClickThreshold;
  }

  bool _qualifiesAsDoubleClick(
    PointerDownEvent event,
    VoidCallback? onDoubleClick,
  ) {
    final lastClickPosition = this.lastClickPosition;
    return onDoubleClick != null &&
        lastClickPosition != null &&
        _isWithinDoubleClickThreshold(event.timeStamp) &&
        (event.position - lastClickPosition).distance <=
            _maxDoubleClickDistance;
  }

  void _clearPendingClick() {
    lastClickTimestamp = null;
    lastClickPosition = null;
  }

  void _clearActiveClick() {
    activeClickTimestamp = Duration.zero;
    activeClickPosition = Offset.zero;
    activeClickMoved = false;
  }

  bool _acceptPointerDown(PointerDownEvent event, VoidCallback? onDoubleClick) {
    if (!_isPrimaryButton(event)) {
      _clearPendingClick();
      _clearActiveClick();
      return false;
    }

    if (_qualifiesAsDoubleClick(event, onDoubleClick)) {
      _clearPendingClick();
      _clearActiveClick();
      onDoubleClick?.call();
      return false;
    }

    activeClickTimestamp = event.timeStamp;
    activeClickPosition = event.position;
    activeClickMoved = false;

    return true;
  }

  void _recordActiveClick() {
    if (!activeClickMoved) {
      lastClickTimestamp = activeClickTimestamp;
      lastClickPosition = activeClickPosition;
    } else {
      _clearPendingClick();
    }

    _clearActiveClick();
  }

  void _onPointerDown(
    PointerDownEvent event,
    double value,
    VoidCallback? onDoubleClick,
  ) {
    if (activePointer != null) {
      return;
    }

    if (!_acceptPointerDown(event, onDoubleClick)) {
      return;
    }

    final size = inputSize;
    if (size == null) {
      _clearActiveClick();
      return;
    }

    activePointer = event.pointer;
    mostRecentLocalPosition = event.localPosition;

    state.startDrag(value);
    _startDirectDrag(
      value: value,
      localPosition: event.localPosition,
      size: size,
    );
  }

  void _startDirectDrag({
    required double value,
    required Offset localPosition,
    required Size size,
  }) {
    final currentRaw = state.scaledToRaw(value);
    final pointerRaw = state.rawForLocalPosition(
      localPosition: localPosition,
      size: size,
    );

    state.resetDragController(rawValue: currentRaw);

    if (state.isOverHandle(
      localPosition: localPosition,
      size: size,
      rawValue: currentRaw,
    )) {
      storedOffsetRaw = pointerRaw - currentRaw;
      lastTargetRaw = currentRaw;
      return;
    }

    storedOffsetRaw = 0;
    lastTargetRaw = pointerRaw;

    final clampedPointerRaw = pointerRaw.clamp(0.0, 1.0).toDouble();
    state.setRawValue(clampedPointerRaw);
    state.resetDragController(rawValue: clampedPointerRaw);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != activePointer) {
      return;
    }

    final size = inputSize;
    if (size == null) {
      return;
    }

    final localDelta = event.localPosition - mostRecentLocalPosition;
    activeClickMoved =
        activeClickMoved || localDelta.dx != 0 || localDelta.dy != 0;
    mostRecentLocalPosition = event.localPosition;

    final pointerRaw = state.rawForLocalPosition(
      localPosition: event.localPosition,
      size: size,
    );
    final targetRaw = pointerRaw - storedOffsetRaw;
    final rawDelta = targetRaw - lastTargetRaw;
    lastTargetRaw = targetRaw;

    state.applyRawDelta(rawDelta);
    state.setHint(hover: false);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != activePointer) {
      return;
    }

    activePointer = null;
    state.endDrag();
    _recordActiveClick();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != activePointer) {
      return;
    }

    activePointer = null;
    state.endDrag();
    _clearActiveClick();
    _clearPendingClick();
  }

  void _onPointerSignal(PointerEvent event, double value) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      state.context,
      listen: false,
    );

    final dxRaw = -event.scrollDelta.dx * 0.35;
    final dyRaw = -event.scrollDelta.dy * 0.35;

    final dx = keyboardModifiers.shift ? dyRaw : dxRaw;
    final dy = keyboardModifiers.shift ? dxRaw : dyRaw;

    state.startDrag(value);
    state.resetDragController(rawValue: state.scaledToRaw(value));
    state.applyPixelDelta(Offset(dx, dy));
    state.endDrag();
  }
}

class _SliderPainter extends CustomPainter {
  final double value;
  final SliderAxis axis;
  final SliderType type;
  final double handleThickness;
  final double handlePressAmount;
  final double borderRadius;
  final bool noBackground;

  const _SliderPainter({
    required this.value,
    required this.axis,
    required this.type,
    required this.handleThickness,
    required this.handlePressAmount,
    required this.borderRadius,
    required this.noBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) {
      return;
    }

    final clampedValue = value.clamp(0.0, 1.0).toDouble();

    final handlePaint = Paint()
      ..color = Color.lerp(
        AnthemTheme.control.active,
        AnthemTheme.control.activePressed,
        handlePressAmount.clamp(0.0, 1.0),
      )!
      ..style = PaintingStyle.fill;

    final trackBackgroundPaint = Paint()
      ..color = AnthemTheme.control.background
      ..style = PaintingStyle.fill;
    final trackBorderPaint = Paint()
      ..color = AnthemTheme.panel.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final activeFillPaint = Paint()
      ..color = AnthemTheme.control.activeBackground
      ..style = PaintingStyle.fill;

    final borderRect = noBackground
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final innerRect = noBackground
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final trackRadius = Radius.circular(borderRadius);
    final innerContentRadius = Radius.circular(
      max(0, max(borderRadius - 1, 1)),
    );
    final borderRRect = RRect.fromRectAndRadius(borderRect, trackRadius);
    final innerContentClipRRect = RRect.fromRectAndRadius(
      innerRect,
      innerContentRadius,
    );

    final handleCenter = switch (axis) {
      SliderAxis.horizontal when noBackground => Offset(
        innerRect.left + innerRect.width * clampedValue,
        innerRect.center.dy,
      ),
      SliderAxis.horizontal => Offset(
        borderRect.left + 1 + (borderRect.width - 2) * clampedValue,
        borderRect.center.dy,
      ),
      SliderAxis.vertical when noBackground => Offset(
        innerRect.center.dx,
        innerRect.bottom - innerRect.height * clampedValue,
      ),
      SliderAxis.vertical => Offset(
        borderRect.center.dx,
        (borderRect.bottom + 1) - (borderRect.height - 2) * clampedValue,
      ),
    };

    canvas.save();
    if (noBackground) {
      canvas.clipRect(innerRect);
    } else {
      canvas.clipRRect(innerContentClipRRect);
      canvas.drawRect(innerRect, trackBackgroundPaint);
    }

    if (axis == SliderAxis.horizontal) {
      if (type == SliderType.normal) {
        final width = (handleCenter.dx - innerRect.left).clamp(
          0.0,
          innerRect.width,
        );
        if (width > 0) {
          final rect = Rect.fromLTWH(
            innerRect.left,
            innerRect.top,
            width,
            innerRect.height,
          );
          canvas.drawRect(rect, activeFillPaint);
        }
      } else {
        final centerX = innerRect.center.dx;
        final clampedHandleX = handleCenter.dx.clamp(
          innerRect.left,
          innerRect.right,
        );
        final left = min(centerX, clampedHandleX);
        final width = (centerX - clampedHandleX).abs();

        if (width > 0) {
          final rect = Rect.fromLTWH(
            left,
            innerRect.top,
            width,
            innerRect.height,
          );
          canvas.drawRect(rect, activeFillPaint);
        }
      }
    } else {
      if (type == SliderType.normal) {
        final height = (innerRect.bottom - handleCenter.dy).clamp(
          0.0,
          innerRect.height,
        );
        if (height > 0) {
          final rect = Rect.fromLTWH(
            innerRect.left,
            innerRect.bottom - height,
            innerRect.width,
            height,
          );
          canvas.drawRect(rect, activeFillPaint);
        }
      } else {
        final centerY = innerRect.center.dy;
        final clampedHandleY = handleCenter.dy.clamp(
          innerRect.top,
          innerRect.bottom,
        );
        final top = min(centerY, clampedHandleY);
        final height = (centerY - clampedHandleY).abs();

        if (height > 0) {
          final rect = Rect.fromLTWH(
            innerRect.left,
            top,
            innerRect.width,
            height,
          );
          canvas.drawRect(rect, activeFillPaint);
        }
      }
    }

    final handleRect = switch (axis) {
      SliderAxis.horizontal => Rect.fromCenter(
        center: handleCenter,
        width: handleThickness,
        height: noBackground ? innerRect.height : innerRect.height - 0.5,
      ),
      SliderAxis.vertical => Rect.fromCenter(
        center: handleCenter,
        width: innerRect.width,
        height: handleThickness,
      ),
    };
    canvas.drawRect(handleRect, handlePaint);
    canvas.restore();

    if (!noBackground) {
      canvas.drawRRect(borderRRect, trackBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.axis != axis ||
        oldDelegate.type != type ||
        oldDelegate.handleThickness != handleThickness ||
        oldDelegate.handlePressAmount != handlePressAmount ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.noBackground != noBackground;
  }
}

enum SliderType { normal, pan }

enum SliderAxis { horizontal, vertical }
