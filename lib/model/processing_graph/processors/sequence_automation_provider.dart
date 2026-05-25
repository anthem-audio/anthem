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

part 'sequence_automation_provider.g.dart';

/// A sequencer-to-processing-graph bridge that outputs automation as live
/// control values.
///
/// See also the C++ implementation in
/// engine/src/modules/processors/sequence_automation_provider.h.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'SequenceAutomationProviderProcessor',
  cppBehaviorClassIncludePath:
      'modules/processors/sequence_automation_provider.h',
)
class SequenceAutomationProviderProcessorModel
    extends _SequenceAutomationProviderProcessorModel
    with
        Processor,
        _$SequenceAutomationProviderProcessorModel,
        _$SequenceAutomationProviderProcessorModelAnthemModelMixin {
  SequenceAutomationProviderProcessorModel({
    required super.nodeId,
    required super.trackId,
    required super.emptyValue,
  });

  SequenceAutomationProviderProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
    required super.trackId,
    required super.emptyValue,
  }) : super(nodeId: idAllocator.allocateId());

  SequenceAutomationProviderProcessorModel.uninitialized()
    : super(nodeId: -1, trackId: -1, emptyValue: 0);

  factory SequenceAutomationProviderProcessorModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$SequenceAutomationProviderProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      controlOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: controlOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.control),
        ),
      ]),
    );
  }

  static int get controlOutputPortId =>
      _SequenceAutomationProviderProcessorModel.controlOutputPortId;
}

abstract class _SequenceAutomationProviderProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int controlOutputPortId = 0;

  Id nodeId;

  /// The automation lane track this node reads from.
  Id trackId;

  /// Emitted only while this lane has no compiled automation data at all.
  ///
  /// Once the lane has automation points, the first point on the track is used
  /// before the first clip and the latest previous point is held between clips.
  double emptyValue;

  _SequenceAutomationProviderProcessorModel({
    required this.nodeId,
    required this.trackId,
    required this.emptyValue,
  });
}
