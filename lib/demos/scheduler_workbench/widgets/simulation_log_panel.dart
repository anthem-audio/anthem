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

import '../simulation/simulation.dart';

class SimulationLogPanel extends StatelessWidget {
  final Simulation simulation;

  const SimulationLogPanel({super.key, required this.simulation});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        border: Border(top: BorderSide(color: Color(0xFF303030))),
      ),
      child: SizedBox(
        height: 220,
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Log',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear log',
                      onPressed: simulation.clearLogs,
                      icon: const Icon(Icons.clear_all),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF303030)),
            Expanded(
              child: Observer(
                builder: (context) {
                  if (simulation.logs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No log entries',
                        style: TextStyle(color: Color(0xFF9A9A9A)),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: simulation.logs.length,
                    itemBuilder: (context, index) {
                      final entry =
                          simulation.logs[simulation.logs.length - 1 - index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SelectableText(
                          '[${entry.time}] ${entry.message}',
                          style: const TextStyle(
                            color: Color(0xFFE6E6E6),
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
