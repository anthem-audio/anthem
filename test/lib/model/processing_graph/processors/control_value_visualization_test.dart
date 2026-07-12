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

import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/control_value_visualization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControlValueVisualizationProcessorModel', () {
    test('creates a one-input, zero-output control sink node', () {
      final processor = ControlValueVisualizationProcessorModel(
        nodeId: 42,
        visualizationId: 'automation-control-value-7-3',
      );

      final node = processor.createNode();

      expect(node.id, 42);
      expect(node.processor, same(processor));
      expect(node.controlInputPorts, hasLength(1));
      expect(node.controlOutputPorts, isEmpty);
      expect(
        node.controlInputPorts.first.id,
        ControlValueVisualizationProcessorModel.controlInputPortId,
      );
      expect(
        node.controlInputPorts.first.config.dataType,
        NodePortDataType.control,
      );
      expect(processor.visualizationId, equals('automation-control-value-7-3'));
      expect(
        ControlValueVisualizationProcessorModel.buildVisualizationId(
          nodeId: 7,
          portId: 3,
        ),
        equals('automation-control-value-7-3'),
      );
    });
  });
}
