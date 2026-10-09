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
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'node_port_config.dart';
import 'parameter_presentation.dart';

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
    ParameterPresentationModel? presentation,
  }) : super(
         connections: AnthemObservableList(),
         presentation: presentation ?? ParameterPresentationModel(),
       ) {
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
        presentation: ParameterPresentationModel(),
      );

  factory NodePortModel.fromJson(Map<String, dynamic> json) =>
      _$NodePortModelAnthemModelMixin.fromJson(json);

  double get parameterResetTarget =>
      parameterResetValue ?? config.parameterConfig?.factoryDefaultValue ?? 0.0;

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

  @hideFromCpp
  ParameterPresentationModel presentation;

  /// The normalized value of the parameter, if this port is a control input
  /// port.
  ///
  /// For third-party plugin parameters, this mirrors the latest value known to
  /// Anthem for UI and automation workflows. It is not restored into the plugin
  /// on engine start; the plugin's opaque processor state is the restore
  /// source.
  @anthemObservable
  double? parameterValue;

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
    required this.presentation,
    this.isAvailable = false,
    this.parameterResetValue,
    this.parameterDisplayText,
  });
}
