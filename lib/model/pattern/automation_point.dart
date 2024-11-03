/*
  Copyright (C) 2023 - 2024 Joshua Wade

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
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'automation_point.g.dart';

@AnthemEnum()
enum AutomationCurveType { smooth, stairs, wave, hold }

@AnthemModel.all()
class AutomationPointModel extends _AutomationPointModel
    with _$AutomationPointModel, _$AutomationPointModelAnthemModelMixin {
  AutomationPointModel.uninitialized()
      : super(
            offset: 0, value: 0, tension: 0, curve: AutomationCurveType.smooth);

  AutomationPointModel({
    required super.offset,
    required super.value,
    super.tension = 0,
    super.curve = AutomationCurveType.smooth,
  });

  factory AutomationPointModel.fromJson(Map<String, dynamic> json) =>
      _$AutomationPointModelAnthemModelMixin.fromJson(json);
}

abstract class _AutomationPointModel with Store, AnthemModelBase {
  late final ID id;

  @anthemObservable
  int offset;

  @anthemObservable
  double value;

  @anthemObservable
  double tension;

  @anthemObservable
  AutomationCurveType curve;

  _AutomationPointModel({
    required this.offset,
    required this.value,
    required this.tension,
    required this.curve,
  }) {
    id = getID();
  }
}
