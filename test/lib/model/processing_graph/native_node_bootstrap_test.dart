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

import 'package:anthem/engine_api/engine.dart';
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
      expect(node.initializationState, NodeInitializationState.uninitialized);
      expect(node.getAllPorts(), isNotEmpty);
      expect(node.getAllPorts().every((port) => !port.isAvailable), isTrue);
      for (final port in [...node.audioInputPorts, ...node.audioOutputPorts]) {
        expect(port.config.channelCount, isNull);
      }
      for (final port in node.controlInputPorts) {
        expect(port.config.parameterConfig, isNull);
        expect(port.parameterValue, isNull);
        expect(port.parameterResetValue, isNull);
      }
      for (final port in node.getAllPorts()) {
        port.isAvailable = true;
      }
      final engineJson = node.toJson(forEngine: true);
      node.markInitialized();
      expect(node.toJson(forEngine: true), engineJson);
      final restored = NodeModel.fromJson(node.toJson());
      expect(
        restored.initializationState,
        NodeInitializationState.uninitialized,
      );
      expect(restored.getAllPorts().every((port) => !port.isAvailable), isTrue);
      expect(
        restored.controlInputPorts.map((port) => port.parameterValue),
        node.controlInputPorts.map((port) => port.parameterValue),
      );
    }
  });

  test('stopping the engine revokes native port confirmations without losing settings', () {
    final project = ProjectModel.create();
    addTearDown(project.dispose);
    for (final node in createNativeProcessorTestNodes(project)) {
      final saved = node.toJson();
      for (final port in node.getAllPorts()) {
        port.isAvailable = true;
      }
      node.markInitialized();
      node.handleEngineStateChange(EngineState.stopped);
      expect(node.initializationState, NodeInitializationState.uninitialized);
      expect(node.getAllPorts().every((port) => !port.isAvailable), isTrue);
      expect(node.toJson(), saved);
    }
  });
}
