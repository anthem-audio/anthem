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

import 'package:anthem/widgets/basic/controls/control_mouse_handler.dart';
import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

export 'package:anthem/widgets/basic/digit_display.dart' show DigitDisplaySize;

class DigitControl extends StatefulWidget {
  final DigitDisplaySize size;
  final int? width;
  final bool monospace;
  final int decimalPlaces;
  final int? minCharacterCount;

  final String? hint;
  final String? hintUnits;

  final double value;
  final void Function()? onStart;
  final void Function(double value)? onChanged;
  final void Function()? onEnd;

  const DigitControl({
    super.key,
    this.size = DigitDisplaySize.normal,
    this.width,
    this.monospace = true,
    this.decimalPlaces = 2,
    this.minCharacterCount,
    this.hint,
    this.hintUnits,
    required this.value,
    this.onStart,
    this.onChanged,
    this.onEnd,
  });

  @override
  State<DigitControl> createState() => _DigitControlState();
}

class _DigitControlState extends State<DigitControl> {
  double startValue = 0;
  double incrementSize = 0;

  void increment(double pixelDelta, int minimumHintPrecision) {
    var valueDelta = pixelDelta * 0.05 * incrementSize;
    valueDelta = (valueDelta / incrementSize).round() * incrementSize;

    final newValue = startValue + valueDelta;
    widget.onChanged?.call(newValue);

    var valueText = widget.value.toStringAsFixed(widget.decimalPlaces);

    final decimalIndex = valueText.indexOf('.');

    if (decimalIndex != -1) {
      while (valueText.endsWith('0') &&
          valueText.length > decimalIndex + 1 + minimumHintPrecision) {
        valueText = valueText.substring(0, valueText.length - 1);
      }
    }

    if (valueText.endsWith('.')) {
      valueText = valueText.substring(0, valueText.length - 1);
    }

    Provider.of<ProjectViewModel>(context, listen: false).hintText =
        '$valueText ${widget.hintUnits ?? ''}';
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
        cursor: SystemMouseCursors.resizeUpDown,
        onStart: () {
          startValue = widget.value;
          incrementSize = 1 / pow(10, i);
          widget.onStart?.call();
        },
        onChange: (e) {
          increment(e.absolute.dy, i);
        },
        onEnd: (e) {
          widget.onEnd?.call();

          // If there is hint text, we should reset back to it
          Provider.of<ProjectViewModel>(context, listen: false).hintText =
              widget.hint ?? '';
        },
        child: Container(
          width: i == 0 ? null : digitWidth,
          // color: i % 2 == 0 ? Color(0xFFFF0000).withAlpha(20) : Color(0xFF00FF00).withAlpha(20),
        ),
      );

      return i == 0 ? Expanded(child: mouseHandlerRegion) : mouseHandlerRegion;
    });

    final text = widget.value
        .toStringAsFixed(widget.decimalPlaces)
        .padLeft(widget.minCharacterCount ?? 0);

    final digitDisplay = DigitDisplay(
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

    if (widget.hint == null) {
      return digitDisplay;
    }

    return MouseRegion(
      onEnter: (e) {
        Provider.of<ProjectViewModel>(context, listen: false).hintText =
            widget.hint!;
      },
      onExit: (e) {
        Provider.of<ProjectViewModel>(context, listen: false).hintText = '';
      },
      child: digitDisplay,
    );
  }
}
