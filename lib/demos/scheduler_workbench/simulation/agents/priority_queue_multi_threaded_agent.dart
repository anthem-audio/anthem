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

import 'package:collection/collection.dart';

import '../../models/node.dart';
import 'simulation_agent.dart';

class PriorityQueueMultiThreadedAgent extends SimulationAgent {
  static const _workerCount = 8;

  final Map<int, int> priorities = {}; // <node ID, priority>
  final Set<int> _queuedNodeIds = {};
  final Set<int> _scheduledNodeIds = {};

  late PriorityQueue<NodeModel> _queue;
  late List<_PriorityQueueWorker> _workers;
  Completer<void>? _runCompleter;
  int? _runVersion;
  int? _runStartTime;
  bool _hasLoggedCompletionReport = false;

  PriorityQueueMultiThreadedAgent({required super.simulation}) {
    _queue = PriorityQueue<NodeModel>(_compareNodes);
    _workers = _createWorkers();
  }

  @override
  SimulationAgentType get type =>
      SimulationAgentType.priorityQueueMultiThreaded;

  @override
  bool get isRunning =>
      (_runCompleter != null && !_runCompleter!.isCompleted) ||
      _workers.any((worker) => worker.isBusy);

  @override
  void prepare() {
    priorities.clear();
    _queuedNodeIds.clear();
    _scheduledNodeIds.clear();
    _queue = PriorityQueue<NodeModel>(_compareNodes);
    _workers = _createWorkers();
    _runCompleter = null;
    _runVersion = simulation.version;
    _runStartTime = null;
    _hasLoggedCompletionReport = false;

    // We do a DFS on the tree, starting at each input node, to calculate
    // priority. High priority node are ones that affect more upstream nodes,
    // and so should be hit first.

    for (final node in simulation.graph.nodes.values) {
      if (_nodeIsInput(node)) {
        _getAndSetPriorities(node);
      }
    }

    for (final node in simulation.graph.nodes.values) {
      if (!priorities.containsKey(node.id)) {
        _getAndSetPriorities(node);
      }
    }

    _enqueueAllReadyNodes();
  }

  @override
  Future<void> run() {
    final existingRun = _runCompleter;

    if (existingRun != null && !existingRun.isCompleted) {
      _scheduleReadyWork();
      return existingRun.future;
    }

    _runVersion = simulation.version;
    _runStartTime ??= simulation.time;
    _runCompleter = Completer<void>();
    _enqueueAllReadyNodes();
    _scheduleReadyWork();
    _completeRunIfFinishedOrStalled();

    return _runCompleter!.future;
  }

  bool _nodeIsInput(NodeModel node) {
    return node.audioInputPorts
        .followedBy(node.controlInputPorts)
        .followedBy(node.eventInputPorts)
        .every((p) => p.connections.isEmpty);
  }

  bool _nodeIsReady(NodeModel node) {
    for (final port
        in node.audioInputPorts
            .followedBy(node.controlInputPorts)
            .followedBy(node.eventInputPorts)) {
      for (final connectionId in port.connections) {
        final connection = simulation.graph.connections[connectionId];

        if (connection == null) {
          return false;
        }

        final sourceNode = simulation.graph.nodes[connection.sourceNodeId];

        if (sourceNode == null ||
            sourceNode.processingState != NodeProcessingState.completed) {
          return false;
        }
      }
    }

    return true;
  }

  Iterable<NodeModel> _downstreamNodes(NodeModel node) {
    final nodes = simulation.graph.nodes;
    final connections = simulation.graph.connections;

    final downstreamNodes = <NodeModel>{};

    for (final port
        in node.audioOutputPorts
            .followedBy(node.controlOutputPorts)
            .followedBy(node.eventOutputPorts)) {
      for (final connectionId in port.connections) {
        final connection = connections[connectionId];

        if (connection == null) {
          continue;
        }

        final downstreamNode = nodes[connection.destinationNodeId];

        if (downstreamNode != null) {
          downstreamNodes.add(downstreamNode);
        }
      }
    }

    return downstreamNodes;
  }

  void _scheduleReadyWork() {
    final runVersion = _runVersion;

    if (runVersion == null || runVersion != simulation.version) {
      return;
    }

    while (_queue.isNotEmpty) {
      final worker = _nextIdleWorker();

      if (worker == null) {
        break;
      }

      final node = _dequeueReadyNode();

      if (node == null) {
        break;
      }

      unawaited(worker.process(node, runVersion));
    }

    _completeRunIfFinishedOrStalled();
  }

  NodeModel? _dequeueReadyNode() {
    while (_queue.isNotEmpty) {
      final node = _queue.removeFirst();
      _queuedNodeIds.remove(node.id);

      if (!_nodeCanBeScheduled(node)) {
        continue;
      }

      _scheduledNodeIds.add(node.id);
      return node;
    }

    return null;
  }

  _PriorityQueueWorker? _nextIdleWorker() {
    for (final worker in _workers) {
      if (!worker.isBusy) {
        return worker;
      }
    }

    return null;
  }

  List<_PriorityQueueWorker> _createWorkers() {
    return List.generate(
      _workerCount,
      (index) => _PriorityQueueWorker(id: index, agent: this),
    );
  }

  void _handleWorkerFinished(NodeModel node, int runVersion) {
    _scheduledNodeIds.remove(node.id);

    if (runVersion != _runVersion || runVersion != simulation.version) {
      return;
    }

    _enqueueReadyDownstreamNodes(node);
    _scheduleReadyWork();
  }

  void _enqueueAllReadyNodes() {
    for (final node in simulation.graph.nodes.values) {
      _enqueueNodeIfReady(node);
    }
  }

  void _enqueueReadyDownstreamNodes(NodeModel node) {
    for (final downstreamNode in _downstreamNodes(node)) {
      _enqueueNodeIfReady(downstreamNode);
    }
  }

  void _enqueueNodeIfReady(NodeModel node) {
    if (!_nodeCanBeQueued(node)) {
      return;
    }

    _queuedNodeIds.add(node.id);
    _queue.add(node);
  }

  bool _nodeCanBeQueued(NodeModel node) {
    return node.processingState == NodeProcessingState.ready &&
        _nodeIsReady(node) &&
        !_queuedNodeIds.contains(node.id) &&
        !_scheduledNodeIds.contains(node.id);
  }

  bool _nodeCanBeScheduled(NodeModel node) {
    return node.processingState == NodeProcessingState.ready &&
        _nodeIsReady(node) &&
        !_scheduledNodeIds.contains(node.id);
  }

  void _completeRunIfFinishedOrStalled() {
    final runCompleter = _runCompleter;

    if (runCompleter == null || runCompleter.isCompleted) {
      return;
    }

    if (_queue.isNotEmpty ||
        _workers.any((worker) => worker.isBusy) ||
        simulation.hasPendingProcesses) {
      return;
    }

    if (simulation.markCompletedIfDone()) {
      _emitCompletionReport();
      runCompleter.complete();
      return;
    }

    simulation.submitError(
      'Priority queue multi-threaded agent stopped before the graph completed '
      'because no nodes were ready.',
    );
    runCompleter.complete();
  }

  int _getAndSetPriorities(NodeModel node) {
    if (priorities[node.id] != null) {
      return priorities[node.id]!;
    }

    var thisPriority = 1;

    for (final downstreamNode in _downstreamNodes(node)) {
      thisPriority += _getAndSetPriorities(downstreamNode);
    }

    priorities[node.id] = thisPriority;
    return thisPriority;
  }

  int _compareNodes(NodeModel a, NodeModel b) {
    final priorityDifference =
        (priorities[b.id] ?? 0) - (priorities[a.id] ?? 0);

    if (priorityDifference != 0) {
      return priorityDifference;
    }

    return a.id - b.id;
  }

  void _emitCompletionReport() {
    if (_hasLoggedCompletionReport) {
      return;
    }

    _hasLoggedCompletionReport = true;

    final startTime = _runStartTime ?? 0;
    final endTime = simulation.completedAtTime ?? simulation.time;
    final runTicks = (endTime - startTime).clamp(0, 1 << 62);
    final totalBusyTicks = _workers.fold<int>(
      0,
      (sum, worker) => sum + worker.busyTicks,
    );
    final totalProcessedNodes = _workers.fold<int>(
      0,
      (sum, worker) => sum + worker.processedNodeCount,
    );
    final totalCapacityTicks = runTicks * _workers.length;
    final overallUtilization = totalCapacityTicks == 0
        ? 0.0
        : totalBusyTicks / totalCapacityTicks * 100;
    final lines = <String>[
      'Priority queue multi-threaded agent completed graph.',
      'Simulation ticks: $runTicks (start $startTime, end $endTime).',
      'Workers: ${_workers.length}.',
      'Processed nodes: $totalProcessedNodes.',
      'Total worker busy ticks: $totalBusyTicks.',
      'Overall worker utilization: ${overallUtilization.toStringAsFixed(1)}%.',
      for (final worker in _workers)
        'Thread ${worker.id + 1}: ${worker.processedNodeCount} nodes, '
            '${worker.busyTicks} busy ticks, '
            '${_formatUtilization(worker.busyTicks, runTicks)} utilization.',
    ];

    simulation.submitLog(lines.join('\n'));
  }

  String _formatUtilization(int busyTicks, int runTicks) {
    if (runTicks == 0) {
      return '0.0%';
    }

    return '${(busyTicks / runTicks * 100).toStringAsFixed(1)}%';
  }
}

class _PriorityQueueWorker {
  final int id;
  final PriorityQueueMultiThreadedAgent agent;

  bool isBusy = false;
  int processedNodeCount = 0;
  int busyTicks = 0;

  _PriorityQueueWorker({required this.id, required this.agent});

  Future<void> process(NodeModel node, int runVersion) async {
    if (isBusy) {
      agent.simulation.submitError(
        'Priority queue worker $id was asked to process ${node.name} while '
        'already busy.',
      );
      return;
    }

    isBusy = true;
    final startTime = agent.simulation.time;

    try {
      for (final connection in agent.simulation.incomingConnectionsForNode(
        node.id,
      )) {
        connection.moveData();
      }

      await node.process();
    } finally {
      busyTicks += (agent.simulation.time - startTime).clamp(0, 1 << 62);

      if (node.processingState == NodeProcessingState.completed) {
        processedNodeCount++;
      }

      isBusy = false;
      agent._handleWorkerFinished(node, runVersion);
    }
  }
}
