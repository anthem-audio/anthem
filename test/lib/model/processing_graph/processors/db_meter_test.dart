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
import 'package:anthem/model/processing_graph/processors/db_meter.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DbMeterProcessorModel', () {
    test('creates a one-input, zero-output node with per-channel IDs', () {
      final processor = DbMeterProcessorModel(
        nodeId: 42,
        publishEverySamples: 480,
        visualizationIds: AnthemObservableList.of([
          'meter_left',
          'meter_right',
        ]),
      );

      final node = processor.createNode();

      expect(node.id, 42);
      expect(node.processor, same(processor));
      expect(node.audioInputPorts, hasLength(1));
      expect(node.audioOutputPorts, isEmpty);
      expect(
        node.audioInputPorts.first.id,
        DbMeterProcessorModel.audioInputPortId,
      );
      expect(
        node.audioInputPorts.first.config.dataType,
        NodePortDataType.audio,
      );
      expect(processor.publishEverySamples, 480);
      expect(processor.visualizationIds, equals(['meter_left', 'meter_right']));
    });
  });
}
