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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/engine_api/messages/messages.dart'
    show ProcessingGraphPortConfiguration;
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'node_port_config.dart';
import 'parameter_config.dart';

part 'node_port.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'NodePort',
  cppBehaviorClassIncludePath: 'modules/processing_graph/model/node_port.h',
)
class NodePortModel extends _NodePortModel
    with _$NodePortModel, _$NodePortModelAnthemModelMixin {
  NodePortModel({
    required super.id,
    required super.nodeId,
    required super.config,
    super.parameterDisplayText,
    super.parameterResetValue,
    super.isAvailable = false,
    double? initialParameterValue,
  }) : super(connections: AnthemObservableList()) {
    if (config.parameterConfig != null) {
      parameterValue =
          initialParameterValue ?? config.parameterConfig!.factoryDefaultValue;
    }
  }

  NodePortModel.uninitialized()
    : super(
        id: -1,
        nodeId: -1,
        config: NodePortConfigModel.uninitialized(),
        connections: AnthemObservableList(),
      );

  factory NodePortModel.fromJson(Map<String, dynamic> json) =>
      _$NodePortModelAnthemModelMixin.fromJson(json);

  /// Applies engine metadata to a new or existing port. Matching parameter
  /// descriptions are updated in place; instance settings and connections are
  /// retained. A factory default fills an unknown parameter value as a preview.
  void applyConfiguration(
    ProcessingGraphPortConfiguration descriptor,
    NodePortDataType dataType,
  ) => runInAction(() {
    config.dataType = dataType;
    config.name = descriptor.name;
    config.channelCount = descriptor.channelCount;
    final defaultValue = descriptor.parameterDefaultValue;
    if (defaultValue == null) {
      config.parameterConfig = null;
      return;
    }

    final parameter = config.parameterConfig ??= ParameterConfigModel(
      id: descriptor.id,
    );
    // Unlike observable metadata, the generated ID setter always notifies.
    if (parameter.id != descriptor.id) parameter.id = descriptor.id;
    parameter.factoryDefaultValue = defaultValue;
    parameter.displayMode = switch (descriptor.parameterDisplayMode) {
      'gainDb' => ParameterDisplayMode.gainDb,
      'pan' => ParameterDisplayMode.pan,
      'pluginText' => ParameterDisplayMode.pluginText,
      _ => ParameterDisplayMode.percent,
    };
    parameter.unitLabel = descriptor.parameterUnitLabel;
    parameter.normalizedVisualBaseline =
        descriptor.parameterNormalizedVisualBaseline ?? 0.0;
    parameterValue ??= defaultValue;
  });

  double get parameterResetTarget =>
      parameterResetValue ?? config.parameterConfig?.factoryDefaultValue ?? 0.0;

  /// Cached base value, falling back to the reset target when none is known.
  /// Pending edits are excluded so undo history uses the earlier setting.
  double get parameterValueOrResetTarget =>
      (parameterValue ?? parameterResetTarget).clamp(0.0, 1.0).toDouble();

  NodePortDataType get type => config.dataType;
}

abstract class _NodePortModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  // Port IDs are unique within their node, data type and direction. For plugin
  // parameter ports, this maps to the plugin's parameter ID.
  int id;

  Id nodeId;

  NodePortConfigModel config;

  /// IDs of all saved connections to or from this port, including connections
  /// whose source or destination port is currently unavailable.
  AnthemObservableList<Id> connections;

  /// False before engine confirmation or while a discovered port is absent.
  @anthemObservable
  @hideFromSerialization
  bool isAvailable;

  /// Optional project/preset reset target, independent of the factory default.
  @anthemObservable
  @hideFromCpp
  double? parameterResetValue;

  /// The last base value confirmed by the engine, normalized to [0, 1].
  /// Saved for display before initialization; processor snapshots restore it.
  @anthemObservable
  @hideFromCpp
  double? parameterValue;

  /// The current requested base value while the engine confirms an edit.
  @anthemObservable
  @hide
  double? pendingParameterValue;

  /// Runtime display text for the current parameter value, usually supplied by
  /// third-party plugins.
  @anthemObservable
  @hide
  String? parameterDisplayText;

  _NodePortModel({
    required this.id,
    required this.nodeId,
    required this.config,
    required this.connections,
    this.isAvailable = false,
    this.parameterResetValue,
    this.parameterDisplayText,
  });
}
