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

import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/instruments/tone_generator.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ToneGeneratorDevice extends StatelessWidget {
  final DeviceModel device;

  const ToneGeneratorDevice({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final node = device.nodeIds
        .map((nodeId) => project.processingGraph.nodes[nodeId])
        .nonNulls
        .where((node) => node.processor is ToneGeneratorProcessorModel)
        .firstOrNull;

    if (node == null) {
      return _InvalidDevice(name: device.name);
    }

    return ToneGenerator(node: node);
  }
}

class _InvalidDevice extends StatelessWidget {
  final String name;

  const _InvalidDevice({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      color: AnthemTheme.panel.accent,
      alignment: Alignment.center,
      child: Text(name, style: TextStyle(color: AnthemTheme.text.main)),
    );
  }
}
