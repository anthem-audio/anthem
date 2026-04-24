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

import 'package:anthem/scheduler_workbench/models/node.dart';
import 'package:anthem/scheduler_workbench/models/node_connection.dart';
import 'package:anthem/scheduler_workbench/models/node_port.dart';
import 'package:anthem/scheduler_workbench/models/processing_graph.dart';
import 'package:anthem/scheduler_workbench/simulation/agents/priority_queue_multi_threaded_agent.dart';
import 'package:anthem/scheduler_workbench/simulation/agents/single_threaded_agent.dart';
import 'package:anthem/scheduler_workbench/simulation/simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

void main() {
  test('process futures complete after the configured ticks pass', () async {
    final graph = ProcessingGraphModel();
    final node = _addNode(graph, name: 'A', processingTicks: 2);
    final simulation = Simulation(graph: graph);

    expect(node.processingState, NodeProcessingState.ready);

    final processFuture = node.process();
    expect(node.processingState, NodeProcessingState.processing);

    simulation.step();
    expect(node.processingState, NodeProcessingState.processing);

    simulation.step();
    await processFuture;

    expect(node.processingState, NodeProcessingState.completed);
    expect(simulation.completedAtTime, 2);
  });

  test('processing validates copied input connections', () async {
    final graph = ProcessingGraphModel();
    final source = _addNode(graph, name: 'Source', processingTicks: 1);
    final destination = _addNode(
      graph,
      name: 'Destination',
      processingTicks: 1,
    );
    final connection = _connect(graph, source, destination);
    final simulation = Simulation(graph: graph);

    final sourceProcess = source.process();
    simulation.step();
    await sourceProcess;

    expect(destination.processingState, NodeProcessingState.ready);

    await destination.process();
    expect(simulation.errors, hasLength(1));
    expect(connection.isCopied, isFalse);

    connection.moveData();
    expect(connection.isCopied, isTrue);
  });

  test('single-threaded agent processes the graph serially', () async {
    final graph = ProcessingGraphModel();
    final source = _addNode(graph, name: 'Source', processingTicks: 2);
    final destination = _addNode(
      graph,
      name: 'Destination',
      processingTicks: 3,
    );
    final connection = _connect(graph, source, destination);
    final simulation = Simulation(graph: graph);
    final agent = SingleThreadedAgent(simulation: simulation);

    final runFuture = agent.run();

    for (var i = 0; i < 5; i++) {
      simulation.step();
      await Future<void>.delayed(Duration.zero);
    }

    await runFuture;

    expect(source.processingState, NodeProcessingState.completed);
    expect(destination.processingState, NodeProcessingState.completed);
    expect(connection.isCopied, isTrue);
    expect(simulation.completedAtTime, 5);
    expect(simulation.errors, isEmpty);
  });

  test('nodes with multiple inputs become ready after all sources finish', () {
    final graph = ProcessingGraphModel();
    final firstSource = _addNode(
      graph,
      name: 'First source',
      processingTicks: 1,
    );
    final secondSource = _addNode(
      graph,
      name: 'Second source',
      processingTicks: 1,
    );
    final destination = _addNode(
      graph,
      name: 'Destination',
      processingTicks: 1,
    );

    _connect(graph, firstSource, destination);
    _connect(graph, secondSource, destination);

    final simulation = Simulation(graph: graph);

    firstSource.process();
    secondSource.process();

    expect(destination.processingState, NodeProcessingState.notReady);

    simulation.step();

    expect(destination.processingState, NodeProcessingState.ready);
  });

  test(
    'priority queue multi-threaded agent starts four nodes at once',
    () async {
      final graph = ProcessingGraphModel();
      final nodes = [
        for (var i = 0; i < 5; i++)
          _addNode(graph, name: 'Node $i', processingTicks: 2),
      ];
      final simulation = Simulation(graph: graph);
      final agent = PriorityQueueMultiThreadedAgent(simulation: simulation);

      agent.prepare();
      final runFuture = agent.run();

      expect(
        nodes
            .where(
              (node) => node.processingState == NodeProcessingState.processing,
            )
            .length,
        4,
      );
      expect(
        nodes
            .where((node) => node.processingState == NodeProcessingState.ready)
            .length,
        1,
      );

      for (var i = 0; i < 4; i++) {
        simulation.step();
        await Future<void>.delayed(Duration.zero);
      }

      await runFuture;

      expect(
        nodes.every(
          (node) => node.processingState == NodeProcessingState.completed,
        ),
        isTrue,
      );
      expect(simulation.errors, isEmpty);
    },
  );

  test(
    'priority queue multi-threaded agent waits for all fan-in inputs',
    () async {
      final graph = ProcessingGraphModel();
      final firstSource = _addNode(
        graph,
        name: 'First source',
        processingTicks: 1,
      );
      final secondSource = _addNode(
        graph,
        name: 'Second source',
        processingTicks: 1,
      );
      final destination = _addNode(
        graph,
        name: 'Destination',
        processingTicks: 1,
      );
      final firstConnection = _connect(graph, firstSource, destination);
      final secondConnection = _connect(graph, secondSource, destination);
      final simulation = Simulation(graph: graph);
      final agent = PriorityQueueMultiThreadedAgent(simulation: simulation);

      agent.prepare();
      final runFuture = agent.run();

      expect(firstSource.processingState, NodeProcessingState.processing);
      expect(secondSource.processingState, NodeProcessingState.processing);
      expect(destination.processingState, NodeProcessingState.notReady);

      simulation.step();
      await Future<void>.delayed(Duration.zero);

      expect(firstConnection.isCopied, isTrue);
      expect(secondConnection.isCopied, isTrue);
      expect(destination.processingState, NodeProcessingState.processing);

      simulation.step();
      await runFuture;

      expect(destination.processingState, NodeProcessingState.completed);
      expect(simulation.errors, isEmpty);
    },
  );

  test('priority queue multi-threaded agent logs utilization report', () async {
    final graph = ProcessingGraphModel();

    for (var i = 0; i < 4; i++) {
      _addNode(graph, name: 'Node $i', processingTicks: 2);
    }

    final simulation = Simulation(graph: graph);
    final agent = PriorityQueueMultiThreadedAgent(simulation: simulation);

    agent.prepare();
    final runFuture = agent.run();

    for (var i = 0; i < 2; i++) {
      simulation.step();
      await Future<void>.delayed(Duration.zero);
    }

    await runFuture;

    expect(simulation.logs, hasLength(1));
    expect(
      simulation.logs.single.message,
      contains('Overall worker utilization: 100.0%.'),
    );
    expect(simulation.logs.single.message, contains('Thread 1: 1 nodes'));
  });
}

NodeModel _addNode(
  ProcessingGraphModel graph, {
  required String name,
  required int processingTicks,
}) {
  final nodeId = graph.allocateId();
  final inputPortId = graph.allocateId();
  final outputPortId = graph.allocateId();
  final node = NodeModel(
    id: nodeId,
    name: name,
    x: 0,
    y: 0,
    audioInputPorts: ObservableList.of([
      NodePortModel(
        id: inputPortId,
        nodeId: nodeId,
        name: 'Audio In',
        dataType: PortDataType.audio,
        direction: PortDirection.input,
      ),
    ]),
    audioOutputPorts: ObservableList.of([
      NodePortModel(
        id: outputPortId,
        nodeId: nodeId,
        name: 'Audio Out',
        dataType: PortDataType.audio,
        direction: PortDirection.output,
      ),
    ]),
  )..setProcessingTicks(processingTicks);

  graph.addNode(node);
  return node;
}

NodeConnectionModel _connect(
  ProcessingGraphModel graph,
  NodeModel source,
  NodeModel destination,
) {
  final connection = NodeConnectionModel(
    id: graph.allocateId(),
    sourceNodeId: source.id,
    sourcePortId: source.audioOutputPorts.first.id,
    destinationNodeId: destination.id,
    destinationPortId: destination.audioInputPorts.first.id,
  );

  graph.addConnection(connection);
  return connection;
}
