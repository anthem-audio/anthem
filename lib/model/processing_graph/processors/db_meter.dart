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

part 'db_meter.g.dart';

/// A processor that measures input peaks and publishes them as dBFS values.
///
/// This node takes one audio input and no outputs. It publishes one
/// visualization stream per input channel using [visualizationIds], and emits a
/// new peak measurement every [publishEverySamples] samples.
///
/// This processor is implemented in the engine at:
/// - `engine/src/modules/processors/db_meter.h`
/// - `engine/src/modules/processors/db_meter.cpp`
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'DbMeterProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/db_meter.h',
)
class DbMeterProcessorModel extends _DbMeterProcessorModel
    with
        Processor,
        _$DbMeterProcessorModel,
        _$DbMeterProcessorModelAnthemModelMixin {
  DbMeterProcessorModel({
    required super.nodeId,
    required super.publishEverySamples,
    required super.visualizationIds,
  });

  DbMeterProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
    required super.publishEverySamples,
    required List<String> visualizationIds,
  }) : super(
         nodeId: idAllocator.allocateId(),
         visualizationIds: AnthemObservableList.of(visualizationIds),
       );

  DbMeterProcessorModel.uninitialized()
    : super(
        nodeId: -1,
        publishEverySamples: 1,
        visualizationIds: AnthemObservableList(),
      );

  factory DbMeterProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$DbMeterProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: audioInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
    );
  }

  static int get audioInputPortId => _DbMeterProcessorModel.audioInputPortId;
}

abstract class _DbMeterProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int audioInputPortId = 0;

  Id nodeId;

  /// Number of input samples per published peak measurement.
  @anthemObservable
  int publishEverySamples;

  /// Visualization IDs used for the published meter values.
  ///
  /// Each item corresponds to one input channel.
  @anthemObservable
  AnthemObservableList<String> visualizationIds;

  _DbMeterProcessorModel({
    required this.nodeId,
    required this.publishEverySamples,
    required this.visualizationIds,
  });
}
