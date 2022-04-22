/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/control_mouse_handler.dart';
import 'package:flutter/widgets.dart';

class VerticalScaleControl extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final Function(double newValue) onChange;

  const VerticalScaleControl({
    Key? key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChange,
  }) : super(key: key);

  @override
  State<VerticalScaleControl> createState() => _VerticalScaleControlState();
}

class _VerticalScaleControlState extends State<VerticalScaleControl> {
  final double handleHeight = 7;
  bool isOver = false;
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color handleColor = Theme.control.main.light;

    if (isPressed) {
      handleColor = Theme.control.hover.dark;
    } else if (isOver) {
      handleColor = Theme.control.hover.light;
    }

    return LayoutBuilder(builder: (context, boxConstraints) {
      return MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        onEnter: (event) {
          setState(() {
            isOver = true;
          });
        },
        onExit: (event) {
          setState(() {
            isOver = false;
          });
        },
        child: ControlMouseHandler(
          allowHorizontalJump: false,
          onStart: () {
            setState(() {
            isPressed = true;
          });
          },
          onEnd: (event) {
            setState(() {
            isPressed = false;
          });
          },
          onChange: (event) {
            widget.onChange((widget.value + event.delta.dy).clamp(widget.min, widget.max));
          },
          child: SizedBox(
            width: 17,
            child: Stack(
              children: [
                Positioned(
                  top: (1 - (widget.value - widget.min) / (widget.max - widget.min)) *
                      (boxConstraints.maxHeight - handleHeight),
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.control.border),
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                      color: handleColor,
                    ),
                    height: handleHeight,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.control.border),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
