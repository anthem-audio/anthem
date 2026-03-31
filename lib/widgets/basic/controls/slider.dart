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
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/util/lazy_follower.dart';
import 'package:flutter/widgets.dart';

import 'control_mouse_handler.dart';
import 'sticky_drag_controller.dart';

const _stickyTrapSize = 0.08;

class Slider extends StatefulWidget {
  final double? width;
  final double? height;
  final SliderAxis axis;
  final SliderType type;
  final double borderRadius;
  final bool noBackground;

  final double value;
  final double min;
  final double max;

  final void Function(double)? onValueChanged;

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
    required this.value,
    this.onValueChanged,
    this.max = 1,
    double? min,
    this.stickyPoints = const [],
    this.hoverHintOverride,
    this.hint,
  }) : min = min ?? (type == SliderType.pan ? -1 : 0),
       assert(borderRadius >= 0);

  @override
  State<Slider> createState() => _SliderState();
}

class _SliderState extends State<Slider> with TickerProviderStateMixin {
  LazyFollowAnimationHelper? animationHelper;
  final StickyDragController dragController = StickyDragController(
    stickyTrapSize: _stickyTrapSize,
  );

  bool isOver = false;
  bool isPressed = false;

  double lastValue = -1;

  double scaledToRaw(double value) =>
      (value - widget.min) / (widget.max - widget.min);
  double rawToScaled(double rawValue) =>
      rawValue * (widget.max - widget.min) + widget.min;

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

    void setHoverAnimationState(bool hover) {
      final [handleSizeHelper, _] = animationHelper!.items;
      handleSizeHelper.setTarget(hover ? 3 : 1);
    }

    void setPressAnimationState(bool pressed) {
      final [_, pressColorHelper] = animationHelper!.items;
      pressColorHelper.setTarget(pressed ? 1 : 0);
    }

    return MouseRegion(
      onEnter: (e) {
        setState(() {
          isOver = true;
        });

        lastValue = widget.value;
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
      child: ControlMouseHandler(
        cursor: switch (widget.axis) {
          SliderAxis.horizontal => SystemMouseCursors.resizeLeftRight,
          SliderAxis.vertical => SystemMouseCursors.resizeUpDown,
        },
        onStart: () {
          setState(() {
            isPressed = true;
          });

          dragController.reset(
            rawValue: scaledToRaw(widget.value),
            stickyPoints: widget.stickyPoints
                .map(scaledToRaw)
                .toList(growable: false),
          );

          lastValue = widget.value;
          setHint(hover: false);

          setPressAnimationState(true);
          animationHelper!.update();
        },
        onEnd: (e) {
          setState(() {
            isPressed = false;
          });

          setPressAnimationState(false);

          if (!isOver) {
            setHoverAnimationState(false);
          }

          animationHelper!.update();
        },
        onChange: (e) {
          if (widget.onValueChanged == null) return;

          final rawPixelChange = switch (widget.axis) {
            SliderAxis.horizontal => e.delta.dx,
            SliderAxis.vertical => e.delta.dy,
          };

          final result = dragController.applyRawDelta(rawPixelChange / 300);
          if (result.changed) {
            final newValue = rawToScaled(result.rawValue);
            widget.onValueChanged?.call(newValue);
            lastValue = newValue;
          }

          setHint(hover: false);
        },
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: animationHelper!.animationController,
            builder: (context, _) {
              final [handleSizeHelper, pressColorHelper] =
                  animationHelper!.items;

              return CustomPaint(
                painter: _SliderPainter(
                  value: scaledToRaw(widget.value),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    clearHint();
    animationHelper?.dispose();
    super.dispose();
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
