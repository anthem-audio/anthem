/*
  Copyright (C) 2022 - 2026 Joshua Wade

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
import 'dart:ui';

import 'package:anthem/color_shifter.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'anthem_color.g.dart';

enum AnthemColorPaletteKind { normal, bright, dark, desaturated, grayscale }

const colorPickerHues = <double>[0, 30, 60, 120, 161, 195, 215, 260, 310];

final normalColorPalette = AnthemColorPalette([
  const Color(0xFF016CB7),
  const Color(0xFFA43E64),
  const Color(0xFF3C7045),
  const Color(0xFF7D41E5),
  const Color(0xFFA73E95),
  const Color(0xFF1367DE),
]);

final brightColorPalette = AnthemColorPalette([
  const Color.fromARGB(255, 209, 68, 212),
  const Color(0xFF21D16D),
  const Color(0xFFD13221),
  const Color(0xFF21C5D1),
  const Color(0xFFD19021),
  const Color.fromRGBO(148, 86, 255, 1),
]);

final darkColorPalette = AnthemColorPalette([
  const Color.fromARGB(255, 0, 62, 106),
  const Color.fromARGB(255, 113, 27, 59),
  const Color.fromARGB(255, 6, 67, 16),
  const Color.fromARGB(255, 39, 9, 90),
  const Color.fromARGB(255, 86, 18, 75),
  const Color.fromARGB(255, 9, 30, 58),
]);

final desaturatedColorPalette = AnthemColorPalette([
  const Color.fromARGB(255, 54, 107, 145),
  const Color.fromARGB(255, 137, 95, 111),
  const Color.fromARGB(255, 98, 127, 103),
  const Color.fromARGB(255, 142, 111, 196),
  const Color.fromARGB(255, 138, 83, 129),
  const Color.fromARGB(255, 87, 128, 185),
]);

Color getColor(double hue, AnthemColorPaletteKind palette) {
  return switch (palette) {
    AnthemColorPaletteKind.normal => normalColorPalette.getColor(hue).toColor(),
    AnthemColorPaletteKind.bright => brightColorPalette.getColor(hue).toColor(),
    AnthemColorPaletteKind.dark => darkColorPalette.getColor(hue).toColor(),
    AnthemColorPaletteKind.desaturated =>
      desaturatedColorPalette.getColor(hue).toColor(),
    AnthemColorPaletteKind.grayscale => const Color(0xFF6C6C6C),
  };
}

@AnthemModel.syncedModel()
class AnthemColor extends _AnthemColor
    with _$AnthemColor, _$AnthemColorAnthemModelMixin {
  AnthemColor({required super.hue, super.palette = .normal});

  AnthemColor.uninitialized() : super(hue: 0, palette: .grayscale);

  factory AnthemColor.fromJson(Map<String, dynamic> json) =>
      _$AnthemColorAnthemModelMixin.fromJson(json);

  AnthemColor clone() {
    return AnthemColor(hue: hue, palette: palette);
  }

  factory AnthemColor.randomHue() {
    return AnthemColor(
      hue: colorPickerHues[Random().nextInt(colorPickerHues.length - 1)],
    );
  }
}

abstract class _AnthemColor with Store, AnthemModelBase {
  @anthemObservable
  double hue;

  @anthemObservable
  AnthemColorPaletteKind palette;

  @hide
  AnthemColorShifter _colorShifter;

  @hide
  (double, AnthemColorPaletteKind) _colorShifterKey;

  AnthemColorShifter get colorShifter {
    if (_colorShifterKey != (hue, palette)) {
      _colorShifter = AnthemColorShifter(getColor(hue, palette));
      _colorShifterKey = (hue, palette);
    }
    return _colorShifter;
  }

  _AnthemColor({required this.hue, required this.palette})
    : _colorShifter = AnthemColorShifter(getColor(hue, palette)),
      _colorShifterKey = (hue, palette),
      super();
}

/// Given a set of two or more colors, this builds a "color wheel" such that a
/// given hue produces a color by interpolating between the two colors with the
/// nearest hues on either side.
class AnthemColorPalette {
  final List<HSLColor> colors;

  AnthemColorPalette(List<Color> inputColors)
    : colors = inputColors.map((c) => HSLColor.fromColor(c)).toList()
        ..sort((a, b) => a.hue.compareTo(b.hue)) {
    assert(inputColors.length >= 2);

    // This asserts that all input colors have distinct hues
    assert(colors.map((c) => c.hue).toSet().length == colors.length);
  }

  HSLColor getColor(double hue) {
    var i1 = colors.length - 1;
    var i2 = 0;

    for (var i = 0; i < colors.length - 1; i++) {
      if (colors[i + 1].hue > hue && colors[i].hue < hue) {
        i1 = i;
        i2 = i + 1;
      }
    }

    final color1 = colors[i1];
    final color2 = colors[i2];

    final hue1 = color1.hue;
    var hue2 = color2.hue;

    if (hue2 < hue1) {
      hue2 += 360.0;
    }
    if (hue < hue1) {
      hue += 360.0;
    }

    assert(hue >= hue1);
    assert(hue <= hue2);

    return lerp(color1, color2, (hue - hue1) / (hue2 - hue1));
  }

  /// Defines lerp between two HSLColors for the purpose of this class.
  ///
  /// This is different than HSLColor.lerp(), in that HSLColor.lerp will go
  /// backwards in hue if a has a larger hue than b, and this method will go
  /// forwards.
  ///
  /// As an example, given that color1 has a hue of 200 and color2 has a hue of
  /// 100 HSLColor.lerp(color1, color2, 0.5) will give a color with a hue of
  /// 150; However, this method will give back a color with a hue of 330 because
  /// that is halfway between the first and second colors if you allow wrapping
  /// around the color wheel.
  @visibleForTesting
  static HSLColor lerp(HSLColor a, HSLColor b, double t) {
    final aHue = a.hue;
    var bHue = b.hue;
    if (aHue > bHue) {
      bHue += 360.0;
    }

    var alpha = lerpDouble(a.alpha, b.alpha, t)!;
    var h = lerpDouble(aHue, bHue, t)! % 360.0;
    var s = lerpDouble(a.saturation, b.saturation, t)!;
    var l = lerpDouble(a.lightness, b.lightness, t)!;

    return HSLColor.fromAHSL(alpha, h, s, l);
  }
}
