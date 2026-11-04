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

import 'dart:async';

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/parameter_controller.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

import '../../helpers/parameter_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;
  late NodeModel node;
  late NodePortModel port;
  late ParameterController controller;
  late ParameterTestEngine engine;
  setUp(() {
    project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);
    final id = project.allocateId();
    port = NodePortModel(
      nodeId: id,
      id: 100,
      config: NodePortConfigModel(
        dataType: NodePortDataType.control,
        parameterConfig: ParameterConfigModel(
          id: 100,
          factoryDefaultValue: 0.25,
        ),
      ),
    );
    node = NodeModel(
      id: id,
      controlInputPorts: AnthemObservableList.of([port]),
    );
    project.processingGraph.addNode(node);
    engine = installParameterTestEngine(project);
    controller = ServiceRegistry.forProject(project.id).parameterController;
  });
  tearDown(() async {
    await project.dispose();
    ServiceRegistry.removeProject(project.id);
  });

  test(
    'commands preserve their target while displaying accepted engine values',
    () async {
      final requests = <double>[];
      var quantize = true;
      engine.processingGraphApi.onEdit = (_, id, value) async {
        requests.add(value);
        return ProcessingGraphParameterValue(
          controlPortId: id,
          value: quantize ? (value * 4).round() / 4 : value,
        );
      };
      final command = SetParameterValueCommand(
        nodeId: node.id,
        controlPortId: port.id,
        oldValue: 0.25,
        newValue: 0.7,
      );
      await project.execute(command);
      expect(port.parameterValue, 0.75);
      expect(command.newValue, 0.7);
      await project.undo();
      expect(port.parameterValue, 0.25);
      await project.redo();
      expect(port.parameterValue, 0.75);
      expect(command.newValue, 0.7);
      expect(requests, [0.7, 0.25, 0.7]);

      // If the engine can now accept the original target, redo still tries it.
      quantize = false;
      await project.undo();
      await project.redo();
      expect(port.parameterValue, 0.7);
      expect(command.newValue, 0.7);
      expect(requests, [0.7, 0.25, 0.7, 0.25, 0.7]);
    },
  );

  test(
    'a gesture displays pending values and commits one accepted undo step',
    () async {
      controller.beginChange(node: node, port: port);
      controller.updateChange(node: node, port: port, value: 0.5);
      controller.updateChange(node: node, port: port, value: 0.75);
      expect(port.pendingParameterValue, 0.75);
      expect(port.parameterValue, 0.25);
      await controller.commitChange(node: node, port: port);
      expect(port.parameterValue, 0.75);
      expect(port.pendingParameterValue, isNull);
      await project.undo();
      expect(port.parameterValue, 0.25);
      await project.redo();
      expect(port.parameterValue, 0.75);
    },
  );

  test('out-of-order confirmations cannot replace a newer edit', () async {
    final replies = <Completer<ProcessingGraphParameterValue>>[];
    engine.processingGraphApi.onEdit = (_, _, _) {
      final reply = Completer<ProcessingGraphParameterValue>();
      replies.add(reply);
      return reply.future;
    };
    final first = controller.setValue(node: node, port: port, value: 0.5);
    final second = controller.setValue(node: node, port: port, value: 0.8);
    replies[1].complete(
      ProcessingGraphParameterValue(controlPortId: port.id, value: 0.8),
    );
    await second;
    replies[0].complete(
      ProcessingGraphParameterValue(controlPortId: port.id, value: 0.5),
    );
    await first;
    expect(port.parameterValue, 0.8);
    expect(port.pendingParameterValue, isNull);
  });

  test(
    'a rejected gesture discards its pending value and adds no history',
    () async {
      engine.processingGraphApi.onEdit = (_, _, _) async =>
          throw StateError('rejected');
      controller.beginChange(node: node, port: port);
      controller.updateChange(node: node, port: port, value: 0.75);
      await expectLater(
        controller.commitChange(node: node, port: port),
        throwsStateError,
      );
      expect(port.parameterValue, 0.25);
      expect(port.pendingParameterValue, isNull);
      await project.undo();
      expect(port.parameterValue, 0.25);
    },
  );

  test('a rejected final drag request preserves earlier accepted work and its undo step', () async {
    final replies = <Completer<ProcessingGraphParameterValue>>[];
    engine.processingGraphApi.onEdit = (_, _, _) {
      final reply = Completer<ProcessingGraphParameterValue>();
      replies.add(reply);
      return reply.future;
    };
    controller.beginChange(node: node, port: port);
    controller.updateChange(node: node, port: port, value: 0.5);
    controller.updateChange(node: node, port: port, value: 0.8);
    final completion = controller.commitChange(node: node, port: port);
    final rejected = expectLater(completion, throwsStateError);
    replies[0].complete(
      ProcessingGraphParameterValue(controlPortId: port.id, value: 0.5),
    );
    await Future<void>.delayed(Duration.zero);
    expect(port.parameterValue, 0.5);
    expect(port.pendingParameterValue, 0.8);
    replies[1].completeError(StateError('rejected'));
    await rejected;
    expect(port.parameterValue, 0.5);
    expect(port.pendingParameterValue, isNull);
    engine.processingGraphApi.onEdit = null;
    await project.undo();
    expect(port.parameterValue, 0.25);
  });

  test(
    'confirmations from an invalidated processor do not update the cache',
    () async {
      final reply = Completer<ProcessingGraphParameterValue>();
      engine.processingGraphApi.onEdit = (_, _, _) => reply.future;
      final edit = controller.setValue(node: node, port: port, value: 0.8);
      final rejected = expectLater(edit, throwsStateError);
      node.resetEngineInitialization();
      reply.complete(
        ProcessingGraphParameterValue(controlPortId: port.id, value: 0.8),
      );
      await rejected;
      expect(port.parameterValue, 0.25);
      expect(port.pendingParameterValue, isNull);
    },
  );

  test(
    'stopped engines reject edits without changing values or history',
    () async {
      engine.running = false;
      expect(
        () => controller.beginChange(node: node, port: port),
        throwsStateError,
      );
      await expectLater(
        project.execute(
          SetParameterValueCommand(
            nodeId: node.id,
            controlPortId: port.id,
            oldValue: 0.25,
            newValue: 0.75,
          ),
        ),
        throwsStateError,
      );
      expect(port.parameterValue, 0.25);
      expect(project.isDirty, isFalse);
    },
  );

  test(
    'engine reports update the confirmed display without an edit or history',
    () async {
      engine.processingGraphApi.onEdit = (_, _, _) =>
          throw StateError('Unexpected edit');
      controller.applyEngineValues(node.id, [
        ProcessingGraphParameterValue(
          controlPortId: port.id,
          value: 0.6,
          displayText: '60%',
        ),
      ]);
      expect(port.parameterValue, 0.6);
      expect(port.parameterDisplayText, '60%');
      expect(project.isDirty, isFalse);
      await project.undo();
      expect(port.parameterValue, 0.6);
    },
  );

  test('MobX observes engine reports and pending edits without model synchronization', () async {
    final observed = <double>[];
    final dispose = autorun(
      (_) => observed.add(port.pendingParameterValue ?? port.parameterValue!),
    );
    addTearDown(dispose.call);
    controller.applyEngineValues(node.id, [
      ProcessingGraphParameterValue(controlPortId: port.id, value: 0.4),
    ]);
    final completion = controller.setValue(node: node, port: port, value: 0.7);
    expect(observed, containsAllInOrder([0.25, 0.4, 0.7]));
    await completion;
    expect(port.parameterValue, 0.7);
    expect(
      (port.toJson(forEngine: true, forProjectFile: false) as Map),
      isNot(contains('parameterValue')),
    );
    expect((port.toJson() as Map)['parameterValue'], 0.7);
  });

  test('unchanged gestures do not create history', () async {
    controller.beginChange(node: node, port: port);
    await controller.commitChange(node: node, port: port);
    expect(node.lastChangedControlPortId, port.id);
    expect(project.isDirty, isFalse);
  });

  test('reset uses the engine API and is undoable', () async {
    await controller.setValue(node: node, port: port, value: 0.75);
    await controller.resetToDefault(node: node, port: port);
    expect(port.parameterValue, 0.25);
    await project.undo();
    expect(port.parameterValue, 0.75);
  });
}
