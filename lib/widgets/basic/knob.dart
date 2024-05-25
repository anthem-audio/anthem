/*
  Copyright (C) 2024 Joshua Wade

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

import 'package:anthem/widgets/util/lazy_follower.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'control_mouse_handler.dart';

class Knob extends StatefulWidget {
  final double? width;
  final double? height;
  final KnobType type;

  final double value;
  final double min;
  final double max;

  final void Function(double)? onValueChanged;

  const Knob({
    super.key,
    this.width,
    this.height,
    this.type = KnobType.normal,
    required this.value,
    this.onValueChanged,
    this.max = 1,
    double? min,
  }) : min = min ?? (type == KnobType.pan ? -1 : 0);

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> with TickerProviderStateMixin {
  LazyFollowAnimationHelper? animationHelper;

  bool isOver = false;
  bool isPressed = false;

  double valueOnPress = -1;

  double get rawValue =>
      (widget.value - widget.min) / (widget.max - widget.min);

  @override
  Widget build(BuildContext context) {
    animationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      items: [
        // Size multiplier
        LazyFollowItem(
          initialValue: 1,
        ),
        // Track size
        LazyFollowItem(
          initialValue: 2,
        ),
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

    return MouseRegion(
      onEnter: (e) {
        setState(() {
          isOver = true;
        });

        setHoverAnimationState(true);
        animationHelper!.update();
      },
      onExit: (e) {
        setState(() {
          isOver = false;
        });

        if (!isPressed) {
          setHoverAnimationState(false);
          animationHelper!.update();
        }
      },
      child: ControlMouseHandler(
        onStart: () {
          setState(() {
            isPressed = true;
          });

          valueOnPress = rawValue;

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

          final rawPixelChange = e.absolute.dy;
          final valueChange = rawPixelChange / 100;

          final newValue =
              (valueOnPress + valueChange).clamp(widget.min, widget.max);

          widget.onValueChanged?.call(
            newValue * (widget.max - widget.min) + widget.min,
          );
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
                  value: rawValue,
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
        radius: multipliedSize.width / 2 - (0.5 + trackSize * 0.5));

    final startAngle = switch (type) {
      KnobType.normal => pi / 2,
      KnobType.pan => -pi / 2,
    };

    final valueAngle = switch (type) {
      KnobType.normal => value * pi * 2,
      KnobType.pan => value * pi,
    };

    // Inner arc
    canvas.drawArc(arcRect, startAngle, valueAngle, false, trackFillPaint);

    // Borders
    canvas.drawCircle(center, multipliedSize.width / 2, trackBorderPaint);
    canvas.drawCircle(
        center, multipliedSize.width / 2 - (trackSize + 1), trackBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.type != type ||
        oldDelegate.sizeMultiplier != sizeMultiplier ||
        oldDelegate.trackSize != trackSize;
  }
}

enum KnobType {
  normal,
  pan,
}
