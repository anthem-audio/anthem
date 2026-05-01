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

import '../../models/node.dart';
import 'simulation_agent.dart';

class SingleThreadedAgent extends SimulationAgent {
  Future<void>? _runFuture;

  SingleThreadedAgent({required super.simulation});

  @override
  SimulationAgentType get type => SimulationAgentType.singleThreaded;

  @override
  bool get isRunning => _runFuture != null;

  @override
  void prepare() {
    _runFuture = null;
  }

  @override
  Future<void> run() {
    final existingRun = _runFuture;

    if (existingRun != null) {
      return existingRun;
    }

    final runVersion = simulation.version;
    late final Future<void> runFuture;

    runFuture = _run(runVersion).whenComplete(() {
      if (identical(_runFuture, runFuture)) {
        _runFuture = null;
      }
    });
    _runFuture = runFuture;

    return runFuture;
  }

  Future<void> _run(int runVersion) async {
    while (runVersion == simulation.version) {
      final node = simulation.takeReadyNode();

      if (node == null) {
        if (!simulation.markCompletedIfDone() &&
            !simulation.hasPendingProcesses) {
          simulation.submitError(
            'Single-threaded agent stopped before the graph completed because '
            'no nodes were ready.',
          );
        }

        return;
      }

      _copyInputs(node);
      await node.process();
    }
  }

  void _copyInputs(NodeModel node) {
    for (final connection in simulation.incomingConnectionsForNode(node.id)) {
      connection.moveData();
    }
  }
}
