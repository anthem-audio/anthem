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
import 'package:flutter/widgets.dart';

const squareSize = 15.0;
const squareMargin = 1.0;
const padding = 4.0;

class ColorPicker extends StatefulWidget {
  const ColorPicker({Key? key}) : super(key: key);

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
    final saturations = [0.0] + List.filled(hueArrayLength, 0.53);

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
          final saturation = saturations[colorIndex];

          return Expanded(
            child: Column(
              children: List.generate(
                3,
                (lightnessIndex) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(squareMargin),
                    color: HSLColor.fromAHSL(
                      1,
                      hue,
                      saturation,
                      lightnessIndex / 4 + 0.25,
                    ).toColor(),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
