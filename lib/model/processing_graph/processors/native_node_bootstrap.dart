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
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/parameter_presentation.dart';
import 'package:anthem_codegen/include.dart';

import 'processor.dart';

/// Constructs routing endpoints and a creation preset before engine discovery.
///
/// Port IDs are an agreed contract with the C++ processor. Availability, channel
/// counts and factory defaults are supplied by that processor during preparation.
NodeModel createNativeNode({
  required Processor processor,
  List<int> audioInputPortIds = const [],
  List<int> audioOutputPortIds = const [],
  List<int> eventInputPortIds = const [],
  List<int> eventOutputPortIds = const [],
  List<int> controlInputPortIds = const [],
  List<int> controlOutputPortIds = const [],
  List<NativeParameterPreset> parameters = const [],
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

  final controlInputs = ports(controlInputPortIds, NodePortDataType.control);
  controlInputs.addAll([
    for (final preset in parameters)
      NodePortModel(
        nodeId: processor.nodeId,
        id: preset.id,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: preset.id,
            displayMode: preset.displayMode,
            unitLabel: preset.unitLabel,
          ),
        ),
        initialParameterValue: preset.value,
        parameterResetValue: preset.value,
        presentation: ParameterPresentationModel(
          normalizedVisualBaseline: preset.normalizedVisualBaseline,
        ),
      ),
  ]);

  return NodeModel(
    id: processor.nodeId,
    processor: processor,
    audioInputPorts: ports(audioInputPortIds, NodePortDataType.audio),
    audioOutputPorts: ports(audioOutputPortIds, NodePortDataType.audio),
    eventInputPorts: ports(eventInputPortIds, NodePortDataType.event),
    eventOutputPorts: ports(eventOutputPortIds, NodePortDataType.event),
    controlInputPorts: controlInputs,
    controlOutputPorts: ports(controlOutputPortIds, NodePortDataType.control),
  );
}

/// Project-owned initial/reset value and provisional formatting for a control.
/// Factory defaults are populated by discovery independently of this preset.
class NativeParameterPreset {
  final int id;
  final double value;
  final ParameterDisplayMode displayMode;
  final String? unitLabel;
  final double normalizedVisualBaseline;

  const NativeParameterPreset({
    required this.id,
    required this.value,
    this.displayMode = ParameterDisplayMode.percent,
    this.unitLabel,
    this.normalizedVisualBaseline = 0.0,
  }) : assert(value >= 0 && value <= 1),
       assert(normalizedVisualBaseline >= 0 && normalizedVisualBaseline <= 1);
}
