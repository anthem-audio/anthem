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

// TODO: Microinteractions

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/control_mouse_handler.dart';
import 'package:flutter/widgets.dart';

class VerticalScaleControl extends StatelessWidget {
  final double min;
  final double max;
  final double value;
  final Function(double newValue) onChange;
  final double handleHeight = 7;

  const VerticalScaleControl({
    Key? key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        return MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: ControlMouseHandler(
            onChange: (event) {
              onChange((value + event.delta.dy).clamp(min, max));
            },
            child: SizedBox(
              width: 17,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.control.border),
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: (1 - (value - min) / max) * (boxConstraints.maxHeight - handleHeight),
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.control.border),
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                        color: Theme.control.main.light,
                      ),
                      height: handleHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}
