/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'automation_point.g.dart';

enum AutomationCurveType { smooth, stairs, wave, hold }

@JsonSerializable()
class AutomationPointModel extends _AutomationPointModel
    with _$AutomationPointModel {
  AutomationPointModel({
    required super.offset,
    required super.value,
    super.tension = 0,
    super.curve = AutomationCurveType.smooth,
  });

  factory AutomationPointModel.fromJson(Map<String, dynamic> json) =>
      _$AutomationPointModelFromJson(json);
}

abstract class _AutomationPointModel with Store {
  late final ID id;

  @observable
  int offset;

  @observable
  double value;

  @observable
  double tension;

  @observable
  AutomationCurveType curve;

  _AutomationPointModel({
    required this.offset,
    required this.value,
    required this.tension,
    required this.curve,
  }) {
    id = getID();
  }

  Map<String, dynamic> toJson() =>
      _$AutomationPointModelToJson(this as AutomationPointModel);
}
