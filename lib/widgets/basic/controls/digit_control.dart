/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/widgets/basic/control_mouse_handler.dart';
import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:flutter/widgets.dart';

export 'package:anthem/widgets/basic/digit_display.dart' show DigitDisplaySize;

class DigitControl extends StatefulWidget {
  final DigitDisplaySize size;
  final int? width;
  final bool monospace;
  final int decimalPlaces;
  final int? minDigitCount;

  final double value;
  final void Function(double value)? onChanged;
  final void Function()? onEnd;

  const DigitControl({
    super.key,
    this.size = DigitDisplaySize.normal,
    this.width,
    this.monospace = true,
    this.decimalPlaces = 2,
    this.minDigitCount,
    required this.value,
    this.onChanged,
    this.onEnd,
  });

  @override
  State<DigitControl> createState() => _DigitControlState();
}

class _DigitControlState extends State<DigitControl> {
  double startValue = 0;
  double incrementSize = 0;

  void increment(double pixelDelta) {
    var valueDelta = pixelDelta * 0.2 * incrementSize;
    valueDelta = (valueDelta / incrementSize).round() * incrementSize;

    final newValue = startValue + valueDelta;
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.decimalPlaces >= 0);

    final double digitWidth = switch (widget.size) {
      DigitDisplaySize.normal => 7,
      DigitDisplaySize.large => 9,
    };

    final mouseHandlerRegions =
        Iterable.generate(widget.decimalPlaces + 1, (i) {
      final mouseHandlerRegion = ControlMouseHandler(
        child: Container(
          width: i == 0 ? null : digitWidth,
          // color: i % 2 == 0 ? Color(0xFFFF0000).withAlpha(20) : Color(0xFF00FF00).withAlpha(20),
        ),
        onStart: () {
          startValue = widget.value;
          incrementSize = 1 / pow(10, i);
        },
        onChange: (e) {
          increment(e.absolute.dy);
        },
        onEnd: (e) {
          widget.onEnd?.call();
        },
      );

      return i == 0 ? Expanded(child: mouseHandlerRegion) : mouseHandlerRegion;
    });

    final text = widget.value
        .toStringAsFixed(widget.decimalPlaces)
        .padLeft(widget.minDigitCount ?? 0);

    return DigitDisplay(
      text: text,
      width: widget.width,
      size: widget.size,
      monospace: widget.monospace,
      overlay: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ...mouseHandlerRegions,
          SizedBox(width: 8),
        ],
      ),
    );
  }
}
