/*
  Copyright (C) 2026 Joshua Wade

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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'control_value_visualization.g.dart';

/// A control-value visualization sink.
///
/// This node reads a control input and publishes the latest normalized value as
/// a visualization stream. It is intended to tap the end of generated
/// automation chains without affecting the destination parameter.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'ControlValueVisualizationProcessor',
  cppBehaviorClassIncludePath:
      'modules/processors/control_value_visualization.h',
)
class ControlValueVisualizationProcessorModel
    extends _ControlValueVisualizationProcessorModel
    with
        Processor,
        _$ControlValueVisualizationProcessorModel,
        _$ControlValueVisualizationProcessorModelAnthemModelMixin {
  ControlValueVisualizationProcessorModel({
    required super.nodeId,
    required super.visualizationId,
  });

  ControlValueVisualizationProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
    required super.visualizationId,
  }) : super(nodeId: idAllocator.allocateId());

  ControlValueVisualizationProcessorModel.uninitialized()
    : super(nodeId: -1, visualizationId: '');

  factory ControlValueVisualizationProcessorModel.fromJson(
    Map<String, dynamic> json,
  ) => _$ControlValueVisualizationProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: controlInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.control),
        ),
      ]),
    );
  }

  static int get controlInputPortId =>
      _ControlValueVisualizationProcessorModel.controlInputPortId;

  static String buildVisualizationId({
    required Id nodeId,
    required int portId,
  }) {
    return 'automation-control-value-$nodeId-$portId';
  }
}

abstract class _ControlValueVisualizationProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int controlInputPortId = 0;

  Id nodeId;

  /// Visualization stream ID used for the published control values.
  @anthemObservable
  String visualizationId;

  _ControlValueVisualizationProcessorModel({
    required this.nodeId,
    required this.visualizationId,
  });
}
