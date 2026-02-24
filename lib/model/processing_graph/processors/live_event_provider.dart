/*
  Copyright (C) 2025 - 2026 Joshua Wade

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
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'live_event_provider.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'LiveEventProviderProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/live_event_provider.h',
)
class LiveEventProviderProcessorModel extends _LiveEventProviderProcessorModel
    with
        Processor,
        _$LiveEventProviderProcessorModel,
        _$LiveEventProviderProcessorModelAnthemModelMixin {
  LiveEventProviderProcessorModel()
    : super(nodeId: 'live-event-provider-${getId()}');

  LiveEventProviderProcessorModel.uninitialized() : super(nodeId: '');

  factory LiveEventProviderProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$LiveEventProviderProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      eventOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: eventOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
    );
  }

  static int get eventOutputPortId =>
      _LiveEventProviderProcessorModel.eventOutputPortId;
}

abstract class _LiveEventProviderProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int eventOutputPortId = 0;

  String nodeId;

  _LiveEventProviderProcessorModel({required this.nodeId});
}
