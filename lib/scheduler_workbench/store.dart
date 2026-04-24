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

import 'generation/generation_settings.dart';
import 'generation/session_generator.dart';
import 'models/processing_graph.dart';
import 'models/session.dart';
import 'simulation/agents/priority_queue_multi_threaded_agent.dart';
import 'simulation/agents/single_threaded_agent.dart';
import 'simulation/agents/simulation_agent.dart';
import 'simulation/simulation.dart';

class WorkbenchStore {
  static final WorkbenchStore instance = WorkbenchStore.demo();

  final ProcessingGraphModel graph;
  final SessionModel session;
  final GenerationSettingsViewModel generationSettings;
  final SessionGenerator sessionGenerator;
  final Simulation simulation;
  final Map<SimulationAgentType, SimulationAgent> agents;
  SimulationAgentType selectedAgentType;

  SimulationAgentType? _preparedAgentType;
  int? _preparedSimulationVersion;

  WorkbenchStore({
    required this.graph,
    required this.session,
    required this.generationSettings,
    required this.sessionGenerator,
    required this.simulation,
    required this.agents,
    this.selectedAgentType = SimulationAgentType.singleThreaded,
  });

  factory WorkbenchStore.demo() {
    final graph = ProcessingGraphModel();
    final simulation = Simulation(graph: graph);
    final store = WorkbenchStore(
      graph: graph,
      session: SessionModel(),
      generationSettings: GenerationSettingsViewModel(),
      sessionGenerator: SessionGenerator(),
      simulation: simulation,
      agents: {
        SimulationAgentType.singleThreaded: SingleThreadedAgent(
          simulation: simulation,
        ),
        SimulationAgentType.priorityQueueMultiThreaded:
            PriorityQueueMultiThreadedAgent(simulation: simulation),
      },
    );

    store.regenerateSession();
    return store;
  }

  void regenerateSession() {
    sessionGenerator.generate(
      graph: graph,
      session: session,
      settings: generationSettings.toSettings(),
    );
    simulation.reset();
    _clearPreparedAgent();
  }

  void playSimulation() {
    _prepareSelectedAgent();
    selectedAgent.run();
    simulation.play();
  }

  void pauseSimulation() {
    simulation.pause();
  }

  void stepSimulation() {
    _prepareSelectedAgent();
    selectedAgent.run();
    simulation.step();
  }

  SimulationAgent get selectedAgent => agents[selectedAgentType]!;

  Iterable<SimulationAgentType> get availableAgentTypes =>
      SimulationAgentType.values;

  void selectAgentType(SimulationAgentType agentType) {
    if (selectedAgentType == agentType) {
      return;
    }

    selectedAgentType = agentType;
    simulation.reset();
    _clearPreparedAgent();
  }

  void _prepareSelectedAgent() {
    if (_preparedAgentType == selectedAgentType &&
        _preparedSimulationVersion == simulation.version) {
      return;
    }

    selectedAgent.prepare();
    _preparedAgentType = selectedAgentType;
    _preparedSimulationVersion = simulation.version;
  }

  void _clearPreparedAgent() {
    _preparedAgentType = null;
    _preparedSimulationVersion = null;
  }
}
