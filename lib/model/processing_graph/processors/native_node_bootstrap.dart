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

import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem_codegen/include.dart';

import 'processor.dart';

/// Constructs stable routing endpoints before engine discovery.
///
/// Port IDs are an agreed contract with the C++ processor. Availability, channel
/// counts and parameter descriptions are supplied during preparation.
NodeModel createNativeNode({
  required Processor processor,
  List<int> audioInputPortIds = const [],
  List<int> audioOutputPortIds = const [],
  List<int> eventInputPortIds = const [],
  List<int> eventOutputPortIds = const [],
  List<int> controlInputPortIds = const [],
  List<int> controlOutputPortIds = const [],
  Map<int, double> initialParameterValues = const {},
}) {
  AnthemObservableList<NodePortModel> ports(
    List<int> ids,
    NodePortDataType type,
  ) => AnthemObservableList.of([
    for (final id in ids)
      NodePortModel(
        nodeId: processor.nodeId,
        id: id,
        config: NodePortConfigModel(dataType: type),
      ),
  ]);

  return NodeModel(
    id: processor.nodeId,
    initialParameterValues: AnthemObservableMap.of(initialParameterValues),
    processor: processor,
    audioInputPorts: ports(audioInputPortIds, NodePortDataType.audio),
    audioOutputPorts: ports(audioOutputPortIds, NodePortDataType.audio),
    eventInputPorts: ports(eventInputPortIds, NodePortDataType.event),
    eventOutputPorts: ports(eventOutputPortIds, NodePortDataType.event),
    controlInputPorts: ports(controlInputPortIds, NodePortDataType.control),
    controlOutputPorts: ports(controlOutputPortIds, NodePortDataType.control),
  );
}
