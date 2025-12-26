/*
  Copyright (C) 2022 - 2024 Joshua Wade

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

import 'package:anthem/color_shifter.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'anthem_color.g.dart';

@AnthemModel.syncedModel()
class AnthemColor extends _AnthemColor
    with _$AnthemColor, _$AnthemColorAnthemModelMixin {
  AnthemColor({
    required super.hue,
    super.lightnessModifier = 1,
    super.saturationModifier = 1,
  });

  AnthemColor.uninitialized()
    : super(hue: 0, lightnessModifier: 1, saturationModifier: 1);

  AnthemColor.randomHue()
    : super(
        hue: (Random().nextInt(12) * 30).toDouble(),
        lightnessModifier: 1,
        saturationModifier: 1,
      );

  factory AnthemColor.fromJson(Map<String, dynamic> json) =>
      _$AnthemColorAnthemModelMixin.fromJson(json);

  AnthemColor clone() {
    return AnthemColor(
      hue: hue,
      lightnessModifier: lightnessModifier,
      saturationModifier: saturationModifier,
    );
  }
}

abstract class _AnthemColor with Store, AnthemModelBase {
  @anthemObservable
  double hue;

  @anthemObservable
  double lightnessModifier; // 1 is normal, + is brighter, - is dimmer

  @anthemObservable
  double saturationModifier; // 1 is normal, 0 is unsaturated

  @hide
  AnthemColorShifter _colorShifter;

  @hide
  (double, double, double) _colorShifterKey;

  AnthemColorShifter get colorShifter {
    if (_colorShifterKey != (hue, lightnessModifier, saturationModifier)) {
      _colorShifter = AnthemColorShifter(
        hue,
        lightnessModifier: lightnessModifier,
        saturationModifier: saturationModifier,
      );
      _colorShifterKey = (hue, lightnessModifier, saturationModifier);
    }
    return _colorShifter;
  }

  _AnthemColor({
    required this.hue,
    required this.lightnessModifier,
    required this.saturationModifier,
  }) : _colorShifter = AnthemColorShifter(
         hue,
         lightnessModifier: lightnessModifier,
         saturationModifier: saturationModifier,
       ),
       _colorShifterKey = (hue, lightnessModifier, saturationModifier),
       super();
}
