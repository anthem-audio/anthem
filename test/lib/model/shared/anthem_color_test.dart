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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnthemColorWheel.lerp()', () {
    test('Normal case', () {
      final color1 = HSLColor.fromAHSL(1.0, 0, 0, 1);
      final color2 = HSLColor.fromAHSL(1.0, 4, 1, 0);

      expect(AnthemColorPalette.lerp(color1, color2, 0).hue, equals(0));
      expect(AnthemColorPalette.lerp(color1, color2, 0.25).hue, equals(1));
      expect(AnthemColorPalette.lerp(color1, color2, 0.5).hue, equals(2));
      expect(AnthemColorPalette.lerp(color1, color2, 0.75).hue, equals(3));
      expect(AnthemColorPalette.lerp(color1, color2, 1).hue, equals(4));

      expect(AnthemColorPalette.lerp(color1, color2, 0).saturation, equals(0));
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.25).saturation,
        equals(0.25),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.5).saturation,
        equals(0.5),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.75).saturation,
        equals(0.75),
      );
      expect(AnthemColorPalette.lerp(color1, color2, 1).saturation, equals(1));

      expect(AnthemColorPalette.lerp(color1, color2, 0).lightness, equals(1));
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.25).lightness,
        equals(0.75),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.5).lightness,
        equals(0.5),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.75).lightness,
        equals(0.25),
      );
      expect(AnthemColorPalette.lerp(color1, color2, 1).lightness, equals(0));
    });

    test('Wrap-around case', () {
      final color1 = HSLColor.fromAHSL(1.0, 358, 0, 1);
      final color2 = HSLColor.fromAHSL(1.0, 2, 1, 0);

      expect(AnthemColorPalette.lerp(color1, color2, 0).hue, equals(358));
      expect(AnthemColorPalette.lerp(color1, color2, 0.25).hue, equals(359));
      expect(AnthemColorPalette.lerp(color1, color2, 0.5).hue, equals(0));
      expect(AnthemColorPalette.lerp(color1, color2, 0.75).hue, equals(1));
      expect(AnthemColorPalette.lerp(color1, color2, 1).hue, equals(2));

      expect(AnthemColorPalette.lerp(color1, color2, 0).saturation, equals(0));
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.25).saturation,
        equals(0.25),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.5).saturation,
        equals(0.5),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.75).saturation,
        equals(0.75),
      );
      expect(AnthemColorPalette.lerp(color1, color2, 1).saturation, equals(1));

      expect(AnthemColorPalette.lerp(color1, color2, 0).lightness, equals(1));
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.25).lightness,
        equals(0.75),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.5).lightness,
        equals(0.5),
      );
      expect(
        AnthemColorPalette.lerp(color1, color2, 0.75).lightness,
        equals(0.25),
      );
      expect(AnthemColorPalette.lerp(color1, color2, 1).lightness, equals(0));
    });
  });

  // Tests AnthemColorWheel, which is responsible for calculating user-selected
  // colors.
  test('AnthemColorWheel', () {
    AnthemColorPalette colorWheel = AnthemColorPalette([
      HSLColor.fromAHSL(1.0, 90, 0.75, 0.75).toColor(),
      HSLColor.fromAHSL(1.0, 270, 0.25, 0.25).toColor(),
    ]);

    expect(colorWheel.getColor(0).hue, equals(0));
    expect(colorWheel.getColor(90).hue, equals(90));
    expect(colorWheel.getColor(180).hue, equals(180));
    expect(colorWheel.getColor(270).hue, equals(270));

    const epsilon = 0.1;

    expect(colorWheel.getColor(0).saturation, epsilonEquals(0.5, epsilon));
    expect(colorWheel.getColor(90).saturation, epsilonEquals(0.75, epsilon));
    expect(colorWheel.getColor(180).saturation, epsilonEquals(0.5, epsilon));
    expect(colorWheel.getColor(270).saturation, epsilonEquals(0.25, epsilon));

    expect(colorWheel.getColor(0).lightness, epsilonEquals(0.5, epsilon));
    expect(colorWheel.getColor(90).lightness, epsilonEquals(0.75, epsilon));
    expect(colorWheel.getColor(180).lightness, epsilonEquals(0.5, epsilon));
    expect(colorWheel.getColor(270).lightness, epsilonEquals(0.25, epsilon));
  });
}

EpsilonEqualsMatcher epsilonEquals(double value, double epsilon) =>
    EpsilonEqualsMatcher(value, epsilon);

class EpsilonEqualsMatcher extends Matcher {
  final double value;
  final double epsilon;

  EpsilonEqualsMatcher(this.value, this.epsilon);

  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    return item is double && (item - value).abs() < epsilon;
  }
}
