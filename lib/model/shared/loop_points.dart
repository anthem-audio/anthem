/*
  Copyright (C) 2025 Joshua Wade

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

part 'loop_points.g.dart';

/// Describes loop points for a pattern or arrangement.
@AnthemModel.syncedModel()
class LoopPointsModel extends _LoopPointsModel
    with _$LoopPointsModel, _$LoopPointsModelAnthemModelMixin {
  LoopPointsModel(super.start, super.end);

  LoopPointsModel.uninitialized() : super(0, 0);

  factory LoopPointsModel.fromJson(Map<String, dynamic> json) =>
      _$LoopPointsModelAnthemModelMixin.fromJson(json);
}

abstract class _LoopPointsModel with Store, AnthemModelBase {
  @anthemObservable
  int start;

  @anthemObservable
  int end;

  _LoopPointsModel(this.start, this.end) : super();
}
