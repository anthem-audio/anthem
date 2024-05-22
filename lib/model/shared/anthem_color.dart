/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'anthem_color.g.dart';

@JsonSerializable()
class AnthemColor extends _AnthemColor with _$AnthemColor {
  AnthemColor({
    required super.hue,
    super.lightnessMultiplier = 1,
    super.saturationMultiplier = 1,
  });

  factory AnthemColor.fromJson(Map<String, dynamic> json) =>
      _$AnthemColorFromJson(json);
}

abstract class _AnthemColor with Store {
  @observable
  double hue;

  @observable
  double lightnessMultiplier; // 1 is normal, + is brighter, - is dimmer

  @observable
  double saturationMultiplier; // 1 is normal, 0 is unsaturated

  _AnthemColor({
    required this.hue,
    required this.lightnessMultiplier,
    required this.saturationMultiplier,
  });

  Map<String, dynamic> toJson() => _$AnthemColorToJson(this as AnthemColor);
}
