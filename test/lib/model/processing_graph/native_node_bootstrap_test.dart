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

import 'package:anthem/model/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/native_processor_test_nodes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native endpoints are provisional until engine discovery', () {
    final project = ProjectModel.create();
    addTearDown(project.dispose);
    for (final node in createNativeProcessorTestNodes(project)) {
      project.processingGraph.addNode(node);
      expect(node.getAllPorts(), isNotEmpty);
      expect(node.getAllPorts().every((port) => !port.isAvailable), isTrue);
      for (final port in [...node.audioInputPorts, ...node.audioOutputPorts]) {
        expect(port.config.channelCount, isNull);
      }
      for (final port in node.controlInputPorts) {
        final parameter = port.config.parameterConfig;
        if (parameter == null) continue;
        expect(parameter.factoryDefaultValue, isNull);
        expect(port.parameterValue, isNotNull);
        expect(port.parameterResetTarget, port.parameterValue);
      }
      for (final port in node.getAllPorts()) {
        port.isAvailable = true;
      }
      final restored = NodeModel.fromJson(node.toJson());
      expect(restored.getAllPorts().every((port) => !port.isAvailable), isTrue);
      expect(
        restored.controlInputPorts.map((port) => port.parameterValue),
        node.controlInputPorts.map((port) => port.parameterValue),
      );
    }
  });
}
