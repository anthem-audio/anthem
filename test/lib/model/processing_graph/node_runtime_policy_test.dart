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
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

void main() {
  test('node policy distinguishes snapshot capture from restoration', () {
    final port = NodePortModel(
      nodeId: 1,
      id: 100,
      config: NodePortConfigModel(
        dataType: NodePortDataType.control,
        parameterConfig: ParameterConfigModel(
          id: 100,
          factoryDefaultValue: 0.25,
        ),
      ),
      initialParameterValue: 0.25,
    );
    final node = NodeModel(
      id: 1,
      processor: GainProcessorModel(nodeId: 1),
      controlInputPorts: AnthemObservableList.of([port]),
    );
    expect(node.canEditParameters, isFalse);
    expect(node.canHandleProcessorEvents, isFalse);
    node.markInitialized();
    port.isAvailable = true;
    final serialized = node.toJson();
    final policies = <(bool, bool)>[];
    final dispose = autorun(
      (_) =>
          policies.add((node.canEditParameters, node.canHandleProcessorEvents)),
    );
    addTearDown(dispose.call);

    node.beginProcessorStateOperation();
    expect(() => node.beginProcessorStateOperation(), throwsStateError);
    expect(
      node.toJson(),
      serialized,
      reason: 'Operation state is runtime-only.',
    );
    port.pendingParameterValue = 0.8;
    node.beginProcessorStateRestoration();
    expect(
      port.isAvailable,
      isTrue,
      reason: 'Cached port descriptions remain valid.',
    );
    expect(port.parameterValue, 0.25);
    expect(port.pendingParameterValue, isNull);
    node.markInitialized(); // Explicit reconciliation can run while events are blocked.
    expect(node.canHandleProcessorEvents, isFalse);
    node.finishProcessorStateRestoration();
    node.finishProcessorStateOperation();
    expect(policies, [
      (true, true),
      (false, true),
      (false, false),
      (false, true),
      (true, true),
    ]);
  });

  test('initialization and operation lifetimes stay independent', () {
    final node = NodeModel(id: 1, processor: GainProcessorModel(nodeId: 1));
    node.markInitialized();
    node.beginProcessorStateOperation();
    node.resetEngineInitialization();
    expect(node.isProcessorStateOperationPending, isTrue);
    expect(() => node.beginProcessorStateOperation(), throwsStateError);
    node.finishProcessorStateOperation();
    expect(node.canEditParameters, isFalse);
    expect(node.canHandleProcessorEvents, isFalse);
    node.markInitialized();
    node.beginProcessorStateOperation();
    node.beginProcessorStateRestoration();
    node.markInitializationFailed();
    node.finishProcessorStateOperation();
    expect(node.canEditParameters, isFalse);
    expect(node.canHandleProcessorEvents, isFalse);
  });
}
