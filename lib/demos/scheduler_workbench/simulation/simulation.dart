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
import 'dart:collection';

import 'package:mobx/mobx.dart';

import '../models/node.dart';
import '../models/node_connection.dart';
import '../models/processing_graph.dart';

part 'simulation.g.dart';

const minSimulationTicksPerFrame = 0.1;
const maxSimulationTicksPerFrame = 10.0;

// ignore: library_private_types_in_public_api
class Simulation = _Simulation with _$Simulation;

class SimulationError {
  final int time;
  final String message;

  const SimulationError({required this.time, required this.message});
}

class SimulationLogEntry {
  final int time;
  final String message;

  const SimulationLogEntry({required this.time, required this.message});
}

class _PendingProcess {
  final int version;
  final NodeModel node;
  final int completeAtTime;
  final Completer<void> completer;

  const _PendingProcess({
    required this.version,
    required this.node,
    required this.completeAtTime,
    required this.completer,
  });
}

abstract class _Simulation with Store {
  final ProcessingGraphModel graph;
  final ObservableList<SimulationError> errors =
      ObservableList<SimulationError>();
  final ObservableList<SimulationLogEntry> logs =
      ObservableList<SimulationLogEntry>();
  final List<_PendingProcess> _pendingProcesses = [];
  final Map<int, List<NodeConnectionModel>> _incomingConnectionsByNodeId = {};
  final Map<int, List<NodeConnectionModel>> _outgoingConnectionsByNodeId = {};
  final Map<int, int> _remainingDependenciesByNodeId = {};
  final Queue<int> _readyNodeIds = Queue<int>();
  final Set<int> _queuedReadyNodeIds = {};

  int _version = 0;

  @observable
  int time = 0;

  @observable
  bool isPlaying = false;

  @observable
  double ticksPerFrame = 1.0;

  @observable
  int? completedAtTime;

  @observable
  int processedNodeCount = 0;

  _Simulation({required this.graph}) {
    reset();
  }

  int get version => _version;

  bool get hasPendingProcesses => _pendingProcesses.isNotEmpty;

  @computed
  int get totalNodeCount => graph.nodes.length;

  @computed
  int get unprocessedNodeCount => totalNodeCount - processedNodeCount;

  @computed
  bool get isComplete => completedAtTime != null;

  @action
  void reset() {
    _version++;

    for (final pendingProcess in _pendingProcesses) {
      if (!pendingProcess.completer.isCompleted) {
        pendingProcess.completer.complete();
      }
    }

    _pendingProcesses.clear();
    time = 0;
    isPlaying = false;
    completedAtTime = null;
    processedNodeCount = 0;
    errors.clear();
    logs.clear();
    _incomingConnectionsByNodeId.clear();
    _outgoingConnectionsByNodeId.clear();
    _remainingDependenciesByNodeId.clear();
    _readyNodeIds.clear();
    _queuedReadyNodeIds.clear();

    for (final node in graph.nodes.values) {
      node
        ..attachSimulation(this as Simulation)
        ..setProcessingState(NodeProcessingState.notReady);
      _remainingDependenciesByNodeId[node.id] = 0;
    }

    for (final connection in graph.connections.values) {
      connection
        ..attachSimulation(this as Simulation)
        ..setCopied(false);

      if (!graph.nodes.containsKey(connection.sourceNodeId) ||
          !graph.nodes.containsKey(connection.destinationNodeId)) {
        continue;
      }

      _outgoingConnectionsByNodeId
          .putIfAbsent(connection.sourceNodeId, () => <NodeConnectionModel>[])
          .add(connection);
      _incomingConnectionsByNodeId
          .putIfAbsent(
            connection.destinationNodeId,
            () => <NodeConnectionModel>[],
          )
          .add(connection);
      _remainingDependenciesByNodeId[connection.destinationNodeId] =
          (_remainingDependenciesByNodeId[connection.destinationNodeId] ?? 0) +
          1;
    }

    for (final node in graph.nodes.values) {
      if ((_remainingDependenciesByNodeId[node.id] ?? 0) == 0) {
        _markNodeReady(node);
      }
    }

    markCompletedIfDone();
  }

  @action
  void play() {
    if (isComplete) {
      return;
    }

    isPlaying = true;
  }

  @action
  void pause() {
    isPlaying = false;
  }

  @action
  void setTicksPerFrame(double value) {
    ticksPerFrame = value
        .clamp(minSimulationTicksPerFrame, maxSimulationTicksPerFrame)
        .toDouble();
  }

  @action
  void step() {
    if (isComplete) {
      return;
    }

    time++;
    _completeDueProcesses();
    markCompletedIfDone();
  }

  @action
  Future<void> processNode(NodeModel node) {
    if (graph.nodes[node.id] != node) {
      submitError('Tried to process node ${node.id}, but it is not in graph.');
      return Future<void>.value();
    }

    if (node.processingState != NodeProcessingState.ready) {
      submitError(
        'Tried to process ${node.name}, but it is '
        '${_describeNodeProcessingState(node.processingState)}.',
      );
      return Future<void>.value();
    }

    final uncopiedInputCount = incomingConnectionsForNode(
      node.id,
    ).where((connection) => !connection.isCopied).length;

    if (uncopiedInputCount > 0) {
      submitError(
        'Tried to process ${node.name}, but $uncopiedInputCount input '
        '${uncopiedInputCount == 1 ? 'connection has' : 'connections have'} '
        'not been copied.',
      );
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _queuedReadyNodeIds.remove(node.id);
    node.setProcessingState(NodeProcessingState.processing);

    _pendingProcesses.add(
      _PendingProcess(
        version: _version,
        node: node,
        completeAtTime: time + node.processingTicks,
        completer: completer,
      ),
    );

    return completer.future;
  }

  @action
  void moveData(NodeConnectionModel connection) {
    if (graph.connections[connection.id] != connection) {
      submitError(
        'Tried to copy connection ${connection.id}, but it is not in graph.',
      );
      return;
    }

    final sourceNode = graph.nodes[connection.sourceNodeId];

    if (sourceNode == null) {
      submitError(
        'Tried to copy connection ${connection.id}, but the source node is '
        'missing.',
      );
      return;
    }

    if (sourceNode.processingState != NodeProcessingState.completed) {
      submitError(
        'Tried to copy data from ${sourceNode.name}, but it is '
        '${_describeNodeProcessingState(sourceNode.processingState)}.',
      );
      return;
    }

    connection.setCopied(true);
  }

  @action
  NodeModel? takeReadyNode() {
    while (_readyNodeIds.isNotEmpty) {
      final nodeId = _readyNodeIds.removeFirst();
      _queuedReadyNodeIds.remove(nodeId);
      final node = graph.nodes[nodeId];

      if (node == null ||
          node.processingState != NodeProcessingState.ready ||
          (_remainingDependenciesByNodeId[nodeId] ?? 0) != 0) {
        continue;
      }

      return node;
    }

    return null;
  }

  @action
  bool markCompletedIfDone() {
    if (graph.nodes.isEmpty ||
        _pendingProcesses.isNotEmpty ||
        completedAtTime != null) {
      return completedAtTime != null;
    }

    if (processedNodeCount != graph.nodes.length) {
      return false;
    }

    completedAtTime = time;
    isPlaying = false;
    return true;
  }

  @action
  void submitError(String message) {
    errors.add(SimulationError(time: time, message: message));
  }

  @action
  void submitLog(String message) {
    logs.add(SimulationLogEntry(time: time, message: message));
  }

  @action
  void clearLogs() {
    logs.clear();
  }

  Iterable<NodeConnectionModel> incomingConnectionsForNode(int nodeId) sync* {
    for (final connection
        in _incomingConnectionsByNodeId[nodeId] ??
            const <NodeConnectionModel>[]) {
      yield connection;
    }
  }

  void _completeDueProcesses() {
    final dueProcesses = _pendingProcesses
        .where((process) => process.completeAtTime <= time)
        .toList(growable: false);

    if (dueProcesses.isEmpty) {
      return;
    }

    _pendingProcesses.removeWhere((process) => process.completeAtTime <= time);

    for (final process in dueProcesses) {
      if (process.version == _version) {
        process.node.setProcessingState(NodeProcessingState.completed);
        processedNodeCount++;
        _markDownstreamNodesReady(process.node);
      }

      if (!process.completer.isCompleted) {
        process.completer.complete();
      }
    }
  }

  void _markDownstreamNodesReady(NodeModel node) {
    for (final connection
        in _outgoingConnectionsByNodeId[node.id] ??
            const <NodeConnectionModel>[]) {
      final destinationNode = graph.nodes[connection.destinationNodeId];

      if (destinationNode == null) {
        continue;
      }

      final remainingDependencies =
          (_remainingDependenciesByNodeId[destinationNode.id] ?? 0) - 1;
      _remainingDependenciesByNodeId[destinationNode.id] =
          remainingDependencies;

      if (remainingDependencies == 0 &&
          destinationNode.processingState == NodeProcessingState.notReady) {
        _markNodeReady(destinationNode);
      }
    }
  }

  void _markNodeReady(NodeModel node) {
    if (node.processingState == NodeProcessingState.processing ||
        node.processingState == NodeProcessingState.completed) {
      return;
    }

    node.setProcessingState(NodeProcessingState.ready);

    if (_queuedReadyNodeIds.add(node.id)) {
      _readyNodeIds.add(node.id);
    }
  }

  String _describeNodeProcessingState(NodeProcessingState state) {
    return switch (state) {
      NodeProcessingState.notReady => 'not ready',
      NodeProcessingState.ready => 'ready',
      NodeProcessingState.processing => 'processing',
      NodeProcessingState.completed => 'already completed',
    };
  }
}
