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

import 'package:flutter/widgets.dart';

const squareSize = 15.0;
const margin = 4.0;

class ColorPicker extends StatelessWidget {
  const ColorPicker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const hueArrayLength = 10;
    final hues = [0.0] +
        List.generate(
          hueArrayLength,
          (i) => i * 360 / hueArrayLength,
        );
    final saturations = [0.0] + List.filled(hueArrayLength, 0.53);

    return SizedBox(
      height: squareSize * 3 + margin * 2,
      child: Row(
        children: List.generate(hues.length, (index) {
          final hue = hues[index];
          final saturation = saturations[index];

          return Container(
            padding: const EdgeInsets.only(
              right: margin,
            ),
            
          );
        }),
      ),
    );
  }
}
