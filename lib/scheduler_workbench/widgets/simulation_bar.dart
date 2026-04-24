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

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter_mobx/flutter_mobx.dart';

import '../simulation/agents/simulation_agent.dart';
import '../simulation/simulation.dart';

class SimulationBar extends StatelessWidget {
  final Simulation simulation;
  final Iterable<SimulationAgentType> agentTypes;
  final SimulationAgentType selectedAgentType;
  final ValueChanged<SimulationAgentType> onAgentChanged;
  final bool isLogPanelOpen;
  final VoidCallback onToggleLogPanel;
  final VoidCallback onPlayPause;
  final VoidCallback onStep;

  const SimulationBar({
    super.key,
    required this.simulation,
    required this.agentTypes,
    required this.selectedAgentType,
    required this.onAgentChanged,
    required this.isLogPanelOpen,
    required this.onToggleLogPanel,
    required this.onPlayPause,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final latestError = simulation.errors.isEmpty
            ? null
            : simulation.errors.last;

        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF171717),
            border: Border(top: BorderSide(color: Color(0xFF303030))),
          ),
          child: SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 310,
                    child: Text(
                      'Nodes: ${simulation.unprocessedNodeCount} / '
                      '${simulation.totalNodeCount} unprocessed',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(child: _ErrorSummary(error: latestError)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 250,
                    child: _AgentSelector(
                      agentTypes: agentTypes,
                      selectedAgentType: selectedAgentType,
                      isEnabled: !simulation.isPlaying,
                      onChanged: onAgentChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 330,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 128,
                          child: Text(
                            '${simulation.ticksPerFrame.toStringAsFixed(1)} '
                            'ticks/frame',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: minSimulationTicksPerFrame,
                            max: maxSimulationTicksPerFrame,
                            value: simulation.ticksPerFrame,
                            onChanged: simulation.setTicksPerFrame,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: simulation.isPlaying ? 'Pause' : 'Play',
                    onPressed: simulation.isComplete ? null : onPlayPause,
                    icon: Icon(
                      simulation.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Step',
                    onPressed: simulation.isComplete ? null : onStep,
                    icon: const Icon(Icons.skip_next),
                  ),
                  IconButton(
                    tooltip: isLogPanelOpen ? 'Hide log' : 'Show log',
                    onPressed: onToggleLogPanel,
                    icon: Icon(
                      isLogPanelOpen
                          ? Icons.keyboard_arrow_down
                          : Icons.article_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SimulationTime(simulation: simulation),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AgentSelector extends StatelessWidget {
  final Iterable<SimulationAgentType> agentTypes;
  final SimulationAgentType selectedAgentType;
  final bool isEnabled;
  final ValueChanged<SimulationAgentType> onChanged;

  const _AgentSelector({
    required this.agentTypes,
    required this.selectedAgentType,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SimulationAgentType>(
        value: selectedAgentType,
        isExpanded: true,
        items: [
          for (final agentType in agentTypes)
            DropdownMenuItem(
              value: agentType,
              child: Text(agentType.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: isEnabled
            ? (value) {
                if (value != null) {
                  onChanged(value);
                }
              }
            : null,
      ),
    );
  }
}

class _ErrorSummary extends StatelessWidget {
  final SimulationError? error;

  const _ErrorSummary({required this.error});

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    if (error == null) {
      return const SizedBox.shrink();
    }

    return Text(
      'Error @ ${error.time}: ${error.message}',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFFFF8A80)),
    );
  }
}

class _SimulationTime extends StatelessWidget {
  final Simulation simulation;

  const _SimulationTime({required this.simulation});

  @override
  Widget build(BuildContext context) {
    final completedAtTime = simulation.completedAtTime;

    return SizedBox(
      width: completedAtTime == null ? 92 : 176,
      child: Text(
        completedAtTime == null
            ? 'Time: ${simulation.time}'
            : 'Time: ${simulation.time} / done: $completedAtTime',
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
