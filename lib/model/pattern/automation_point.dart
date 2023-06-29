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

import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'automation_point.g.dart';

@JsonSerializable()
class AutomationPointModel extends _AutomationPointModel
    with _$AutomationPointModel {
  AutomationPointModel() : super();

  factory AutomationPointModel.fromJson(Map<String, dynamic> json) =>
      _$AutomationPointModelFromJson(json);
}

abstract class _AutomationPointModel with Store {
  _AutomationPointModel();

  Map<String, dynamic> toJson() =>
      _$AutomationPointModelToJson(this as AutomationPointModel);
}
