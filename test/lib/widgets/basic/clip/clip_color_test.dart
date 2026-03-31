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

import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getBaseColor', () {
    final color = AnthemColor(hue: 120);

    test('hovered clip color is lighter than base clip color', () {
      final baseColor = getBaseColor(
        color: color,
        selected: false,
        pressed: false,
      );
      final hoveredColor = getBaseColor(
        color: color,
        selected: false,
        pressed: false,
        hovered: true,
      );

      expect(
        HSLColor.fromColor(hoveredColor).lightness,
        greaterThan(HSLColor.fromColor(baseColor).lightness),
      );
    });

    test('pressed clip color takes precedence over hovered clip color', () {
      final pressedColor = getBaseColor(
        color: color,
        selected: false,
        pressed: true,
      );
      final pressedHoveredColor = getBaseColor(
        color: color,
        selected: false,
        pressed: true,
        hovered: true,
      );

      expect(pressedHoveredColor, pressedColor);
    });
  });
}
