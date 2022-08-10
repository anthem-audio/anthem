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

import 'package:freezed_annotation/freezed_annotation.dart';

part 'anthem_color.g.dart';

@JsonSerializable()
class AnthemColor {
  double hue;
  double brightnessModifier; // 0 is normal, + is brighter, - is dimmer
  double saturationMultiplier; // 1 is normal, 0 is unsaturated

  AnthemColor({
    required this.hue,
    this.brightnessModifier = 0,
    this.saturationMultiplier = 1,
  });

  factory AnthemColor.fromJson(Map<String, dynamic> json) =>
      _$AnthemColorFromJson(json);

  Map<String, dynamic> toJson() => _$AnthemColorToJson(this);
}
