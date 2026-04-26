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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'canvas/graph_canvas.dart';
import 'simulation/agents/simulation_agent.dart';
import 'store.dart';
import 'view_model.dart';
import 'widgets/generation_panel.dart';
import 'widgets/simulation_log_panel.dart';
import 'widgets/simulation_bar.dart';

class WorkbenchApp extends StatefulWidget {
  const WorkbenchApp({super.key});

  @override
  State<WorkbenchApp> createState() => _WorkbenchAppState();
}

class _WorkbenchAppState extends State<WorkbenchApp>
    with SingleTickerProviderStateMixin {
  late final WorkbenchStore store = WorkbenchStore.instance;
  late final WorkbenchViewModel viewModel = WorkbenchViewModel();
  late final Ticker _simulationTicker;

  double _tickAccumulator = 0;
  bool _isAdvancingSimulation = false;
  bool _isLogPanelOpen = true;

  @override
  void initState() {
    super.initState();
    _simulationTicker = createTicker(_handleSimulationFrame);
  }

  @override
  void dispose() {
    _simulationTicker.dispose();
    super.dispose();
  }

  void _regenerateSession() {
    _simulationTicker.stop();
    _tickAccumulator = 0;
    _isAdvancingSimulation = false;
    store.regenerateSession();
    viewModel.viewportOffset = Offset.zero;
  }

  void _togglePlayback() {
    if (store.simulation.isPlaying) {
      store.pauseSimulation();
      _simulationTicker.stop();
      _tickAccumulator = 0;
      return;
    }

    store.playSimulation();

    if (store.simulation.isPlaying && !_simulationTicker.isActive) {
      _simulationTicker.start();
    }
  }

  void _stepSimulation() {
    store.stepSimulation();
  }

  void _resetSimulation() {
    _simulationTicker.stop();
    _tickAccumulator = 0;
    _isAdvancingSimulation = false;
    store.resetSimulation();
  }

  void _selectAgentType(SimulationAgentType agentType) {
    _simulationTicker.stop();
    _tickAccumulator = 0;
    _isAdvancingSimulation = false;

    setState(() {
      store.selectAgentType(agentType);
    });
  }

  void _toggleLogPanel() {
    setState(() {
      _isLogPanelOpen = !_isLogPanelOpen;
    });
  }

  void _handleSimulationFrame(Duration elapsed) {
    if (!store.simulation.isPlaying) {
      _simulationTicker.stop();
      _tickAccumulator = 0;
      return;
    }

    if (_isAdvancingSimulation) {
      return;
    }

    _tickAccumulator += store.simulation.ticksPerFrame;
    final stepCount = _tickAccumulator.floor();

    if (stepCount <= 0) {
      return;
    }

    _tickAccumulator -= stepCount;
    _isAdvancingSimulation = true;
    final simulationVersion = store.simulation.version;
    unawaited(
      _advanceSimulationSteps(stepCount, simulationVersion).whenComplete(() {
        _isAdvancingSimulation = false;

        if (!store.simulation.isPlaying) {
          _simulationTicker.stop();
          _tickAccumulator = 0;
        }
      }),
    );
  }

  Future<void> _advanceSimulationSteps(
    int stepCount,
    int simulationVersion,
  ) async {
    for (var i = 0; i < stepCount; i++) {
      if (!store.simulation.isPlaying ||
          store.simulation.version != simulationVersion) {
        break;
      }

      store.simulation.step();

      // Let process futures resume so an agent can schedule more work between
      // ticks even when the UI advances multiple ticks in one frame.
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scheduler Workbench',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Scheduler Workbench')),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  GenerationPanel(
                    settings: store.generationSettings,
                    onRegenerate: _regenerateSession,
                  ),
                  Expanded(
                    child: GraphCanvas(
                      graph: store.graph,
                      viewModel: viewModel,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLogPanelOpen)
              SimulationLogPanel(simulation: store.simulation),
            SimulationBar(
              simulation: store.simulation,
              agentTypes: store.availableAgentTypes,
              selectedAgentType: store.selectedAgentType,
              onAgentChanged: _selectAgentType,
              isLogPanelOpen: _isLogPanelOpen,
              onToggleLogPanel: _toggleLogPanel,
              onReset: _resetSimulation,
              onPlayPause: _togglePlayback,
              onStep: _stepSimulation,
            ),
          ],
        ),
      ),
    );
  }
}
