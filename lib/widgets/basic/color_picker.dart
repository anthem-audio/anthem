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

import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';

const squareSize = 15.0;
const squareMargin = 1.0;
const padding = 4.0;

class ColorPicker extends StatefulWidget {
  final void Function(AnthemColor)? onChange;

  const ColorPicker({super.key, this.onChange});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  @override
  Widget build(BuildContext context) {
    const hueArrayLength = 10;
    final hues = [0.0] +
        List.generate(
          hueArrayLength,
          (i) => i * 360 / hueArrayLength,
        );
    final saturations = [0.0] + List.filled(hueArrayLength, 1);

    return Container(
      decoration: BoxDecoration(
        color: Theme.panel.accentDark,
        border: Border.all(color: Theme.panel.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(padding),
      height: squareSize * 3 + squareMargin * 6 + padding * 2,
      child: Row(
        children: List.generate(hues.length, (colorIndex) {
          final hue = hues[colorIndex];
          final saturation = saturations[colorIndex] * 0.53;

          return Expanded(
            child: Column(
              children: List.generate(
                3,
                (lightnessIndex) {
                  var lightnessMultiplier = 0.9 + (lightnessIndex - 1) * 0.5;
                  if (lightnessIndex == 0) lightnessMultiplier += 0.2;

                  final saturationMultiplier = saturations[colorIndex] +
                      (lightnessIndex - 1) * 0.5 -
                      0.2;

                  void onPointerUp(PointerEvent e) {
                    widget.onChange?.call(AnthemColor(
                      hue: hue,
                      saturationMultiplier: saturationMultiplier,
                      lightnessMultiplier: lightnessMultiplier,
                    ));
                  }

                  return Expanded(
                    child: Listener(
                      onPointerUp: onPointerUp,
                      onPointerCancel: onPointerUp,
                      child: Container(
                        margin: const EdgeInsets.all(squareMargin),
                        color: HSLColor.fromAHSL(
                          1,
                          hue,
                          (saturation * saturationMultiplier).clamp(0, 1),
                          (0.5 * lightnessMultiplier).clamp(0, 1),
                        ).toColor(),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}
