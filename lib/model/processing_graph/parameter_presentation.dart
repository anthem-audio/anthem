/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

part 'parameter_presentation.g.dart';

/// Project-owned appearance, independent of processor-discovered metadata.
@AnthemModel.syncedModel()
class ParameterPresentationModel extends _ParameterPresentationModel
    with
        _$ParameterPresentationModel,
        _$ParameterPresentationModelAnthemModelMixin {
  ParameterPresentationModel({super.normalizedVisualBaseline = 0.0})
    : assert(normalizedVisualBaseline >= 0 && normalizedVisualBaseline <= 1);

  ParameterPresentationModel.uninitialized() : super();

  factory ParameterPresentationModel.fromJson(Map<String, dynamic> json) {
    final baseline = json['normalizedVisualBaseline'];
    if (baseline is! num ||
        !baseline.isFinite ||
        baseline < 0 ||
        baseline > 1) {
      throw const FormatException(
        'Parameter visual baseline must be in [0, 1].',
      );
    }
    return _$ParameterPresentationModelAnthemModelMixin.fromJson(json);
  }
}

abstract class _ParameterPresentationModel with Store, AnthemModelBase {
  /// Normalized value from which knob arcs and automation shading extend.
  @anthemObservable
  @hideFromCpp
  double normalizedVisualBaseline;

  _ParameterPresentationModel({this.normalizedVisualBaseline = 0.0});
}
