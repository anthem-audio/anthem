/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/instruments/tone_generator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class ChannelRack extends StatefulWidget {
  const ChannelRack({super.key});

  @override
  State<ChannelRack> createState() => _ChannelRackState();
}

class _ChannelRackState extends State<ChannelRack> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.panel.main,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Container(width: 130, color: const Color(0x11FFFFFF)),
            const Expanded(child: _ProcessorList()),
          ],
        ),
      ),
    );
  }
}

class _ProcessorList extends StatefulObserverWidget {
  const _ProcessorList();

  @override
  State<_ProcessorList> createState() => __ProcessorListState();
}

class __ProcessorListState extends State<_ProcessorList> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    final activeInstrumentId = project.activeInstrumentID;

    if (activeInstrumentId == null) {
      return Container(
        color: Theme.panel.accentDark,
        child: Center(
          child: Text(
            'No instrument selected',
            style: TextStyle(color: Theme.text.main),
          ),
        ),
      );
    }

    return Container(
      color: Theme.panel.accentDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Container(
              width: 28,
              decoration: BoxDecoration(
                color: Theme.panel.main,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            _buildChild(project, activeInstrumentId),
          ],
        ),
      ),
    );
  }
}

Widget _buildChild(ProjectModel project, String activeInstrumentId) {
  final instrument = project.generators[activeInstrumentId];

  if (instrument == null) {
    return const Text('Invalid instrument');
  }

  final node = project.processingGraph.nodes[instrument.generatorNodeId];

  if (node == null) {
    return const Text('Invalid instrument');
  }

  return switch (node.processor) {
    ToneGeneratorProcessorModel _ => ToneGenerator(node: node),
    _ => const Text('Invalid instrument'),
  };
}
