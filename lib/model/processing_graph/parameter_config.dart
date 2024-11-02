/*
  Copyright (C) 2024 Joshua Wade

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

import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'parameter_config.g.dart';

@AnthemModel.all()
class ParameterConfigModel extends _ParameterConfigModel
    with _$ParameterConfigModel, _$ParameterConfigModelAnthemModelMixin {
  ParameterConfigModel({
    required super.defaultValue,
    required super.minimumValue,
    required super.maximumValue,
    required super.smoothingDurationSeconds,
  });

  ParameterConfigModel.uninitialized()
      : super(
          defaultValue: 0.0,
          minimumValue: 0.0,
          maximumValue: 1.0,
          smoothingDurationSeconds: 0.0,
        );

  factory ParameterConfigModel.fromJson(Map<String, dynamic> json) =>
      _$ParameterConfigModelAnthemModelMixin.fromJson(json);
}

abstract class _ParameterConfigModel extends Hydratable
    with Store, AnthemModelBase {
  double defaultValue;
  double minimumValue;
  double maximumValue;
  double smoothingDurationSeconds;

  _ParameterConfigModel({
    required this.defaultValue,
    required this.minimumValue,
    required this.maximumValue,
    required this.smoothingDurationSeconds,
  }) {
    isHydrated = true;
    (this as _$ParameterConfigModelAnthemModelMixin).init();
  }
}
