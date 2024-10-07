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

import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'automation_point.dart';

part 'automation_lane.g.dart';

/// Represents a set of automation points for a particular channel.
@AnthemModel.all()
class AutomationLaneModel extends _AutomationLaneModel
    with _$AutomationLaneModel, _$AutomationLaneModelAnthemModelMixin {
  AutomationLaneModel() : super();

  factory AutomationLaneModel.fromJson(Map<String, dynamic> json) =>
      _$AutomationLaneModelAnthemModelMixin.fromJson(json);
}

abstract class _AutomationLaneModel with Store, AnthemModelBase {
  _AutomationLaneModel();

  /// The automation points for this lane. The first point should always have a
  /// time of 0.
  @anthemObservable
  ObservableList<AutomationPointModel> points = ObservableList();
}
