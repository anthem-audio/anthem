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

import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'parameter_config.g.dart';

@AnthemEnum()
enum ParameterDisplayMode { percent, gainDb, pan, pluginText }

/// A model representing the configuration of a parameter for a node in the
/// processing graph.
///
/// All nodes in the processing graph have input ports and output ports. These
/// inputs and outputs can be of either audio, event or control types. Control
/// ports that are inputs are also parameters. This model represents the
/// configuration of a parameter.
///
/// A parameter is a value that can be set statically, or can be controlled by a
/// control signal. If a parameter is controlled by a control signal, the set
/// value will be ignored.
///
/// This class is responsible for storing the configuration of a parameter in
/// the processing graph. Parameter values are always stored normalized in the
/// range [0, 1]. This config stores the default normalized value.
@AnthemModel.syncedModel()
class ParameterConfigModel extends _ParameterConfigModel
    with _$ParameterConfigModel, _$ParameterConfigModelAnthemModelMixin {
  ParameterConfigModel({
    required super.id,
    required super.defaultValue,
    super.displayMode = ParameterDisplayMode.percent,
    super.unitLabel,
    super.normalizedVisualBaseline = 0.0,
  }) : assert(normalizedVisualBaseline >= 0 && normalizedVisualBaseline <= 1);

  ParameterConfigModel.uninitialized()
    : super(
        id: 0,
        defaultValue: 0.0,
        displayMode: ParameterDisplayMode.percent,
      );

  factory ParameterConfigModel.fromJson(Map<String, dynamic> json) {
    final baseline = json.containsKey('normalizedVisualBaseline')
        ? json['normalizedVisualBaseline']
        : 0.0;
    if (baseline is! num ||
        !baseline.isFinite ||
        baseline < 0 ||
        baseline > 1) {
      throw const FormatException(
        'Parameter visual baseline must be in [0, 1].',
      );
    }
    return _$ParameterConfigModelAnthemModelMixin.fromJson({
      ...json,
      'normalizedVisualBaseline': baseline,
    });
  }
}

abstract class _ParameterConfigModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  /// The ID associated with this parameter.
  ///
  /// This must match the control input port ID for this parameter. For plugin
  /// parameter ports, this maps to the plugin's parameter ID.
  int id;

  /// The default normalized value of the parameter.
  double defaultValue;

  /// Normalized value from which knob arcs and automation shading extend.
  /// Independent of the display format, current value and reset default.
  @anthemObservable
  @hideFromCpp
  double normalizedVisualBaseline;

  /// How normalized values should be displayed in the UI.
  ParameterDisplayMode? displayMode;

  /// Optional unit label for display text, such as "Hz" or "dB".
  String? unitLabel;

  _ParameterConfigModel({
    required this.id,
    required this.defaultValue,
    this.displayMode,
    this.unitLabel,
    this.normalizedVisualBaseline = 0.0,
  });
}
