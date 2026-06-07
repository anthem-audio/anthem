/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/lazy_follower.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'control_mouse_handler.dart';
import 'parameter_ui_binding.dart';
import 'sticky_drag_controller.dart';

export 'parameter_ui_binding.dart';

const _stickyTrapSize = 0.08;

class Knob extends StatefulWidget {
  final double? width;
  final double? height;
  final KnobType type;

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

  const Knob({
    super.key,
    this.width,
    this.height,
    this.type = KnobType.normal,
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
  }) : min = min ?? (type == KnobType.pan ? -1 : 0),
       assert(value != null || parameter != null);

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> with TickerProviderStateMixin {
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
        // Size multiplier
        LazyFollowItem(initialValue: 1),
        // Track size
        LazyFollowItem(initialValue: 2),
      ],
    );

    void setHoverAnimationState(bool hover) {
      final [_, trackSizeHelper] = animationHelper!.items;
      trackSizeHelper.setTarget(hover ? 3 : 2);
    }

    void setPressAnimationState(bool pressed) {
      final [sizeMultiplierHelper, _] = animationHelper!.items;
      sizeMultiplierHelper.setTarget(pressed ? 0.9 : 1);
    }

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

      return MouseRegion(
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
        child: ControlMouseHandler(
          onDoubleClick: widget.parameter == null
              ? null
              : resetParameterToDefault,
          onStart: () {
            setState(() {
              isPressed = true;
            });

            dragController.reset(
              rawValue: scaledToRaw(value),
              stickyPoints: widget.stickyPoints
                  .map(scaledToRaw)
                  .toList(growable: false),
            );

            lastValue = value;
            widget.parameter?.beginChange();
            widget.onValueChangeStart?.call();

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

            widget.parameter?.commitChange();
            widget.onValueChangeEnd?.call(lastValue);
          },
          onChange: (e) {
            if (widget.parameter == null && widget.onValueChanged == null) {
              return;
            }

            final result = dragController.applyRawDelta(e.delta.dy / 300);
            if (result.changed) {
              final newValue = rawToScaled(result.rawValue);
              widget.parameter?.updateChange(newValue);
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
                final [sizeMultiplierHelper, trackSizeHelper] =
                    animationHelper!.items;

                return CustomPaint(
                  painter: _KnobPainter(
                    value: scaledToRaw(value),
                    type: widget.type,
                    sizeMultiplier: sizeMultiplierHelper.animation.value,
                    trackSize: trackSizeHelper.animation.value,
                  ),
                );
              },
            ),
          ),
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
            return buildControl(
              automationParameterValue: engineTime == null ? null : value,
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    animationHelper!.dispose();
    super.dispose();
  }
}

class _KnobPainter extends CustomPainter {
  final double value;
  final KnobType type;
  final double sizeMultiplier;
  final double trackSize;

  _KnobPainter({
    required this.value,
    required this.type,
    required this.sizeMultiplier,
    required this.trackSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final multipliedSize = size * sizeMultiplier;

    final trackBorderPaint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final trackFillPaint = Paint()
      ..color = const Color(0xFF28D1AA)
      ..strokeWidth = trackSize
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    final arcRect = Rect.fromCircle(
      center: center,
      radius: multipliedSize.width / 2 - (0.5 + trackSize * 0.5),
    );

    final startAngle = switch (type) {
      KnobType.normal => pi / 2,
      KnobType.pan => -pi / 2,
    };

    final valueAngle = switch (type) {
      KnobType.normal => value * pi * 2,
      KnobType.pan => (value - 0.5) * pi * 2,
    };

    // Inner arc
    canvas.drawArc(arcRect, startAngle, valueAngle, false, trackFillPaint);

    // Borders
    canvas.drawCircle(center, multipliedSize.width / 2, trackBorderPaint);
    canvas.drawCircle(
      center,
      multipliedSize.width / 2 - (trackSize + 1),
      trackBorderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.type != type ||
        oldDelegate.sizeMultiplier != sizeMultiplier ||
        oldDelegate.trackSize != trackSize;
  }
}

enum KnobType { normal, pan }
