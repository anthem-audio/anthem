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

import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class UtilityDevice extends StatelessWidget {
  final DeviceModel device;

  const UtilityDevice({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context, listen: false);
    final node = device.nodeIds
        .map((nodeId) => project.processingGraph.nodes[nodeId])
        .nonNulls
        .where((node) => node.processor is UtilityProcessorModel)
        .firstOrNull;

    if (node == null) {
      return _InvalidUtilityDevice(name: device.name);
    }

    return SizedBox(
      width: 104,
      child: Center(
        child: SizedBox(
          width: 88,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              _GainControl(node: node),
              _BalanceControl(node: node),
            ],
          ),
        ),
      ),
    );
  }
}

class _GainControl extends StatelessWidget {
  final NodeModel node;

  const _GainControl({required this.node});

  @override
  Widget build(BuildContext context) {
    final gainParameter = ParameterControlBinding.byId(
      node: node,
      portId: UtilityProcessorModel.gainPortId,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Knob(
          parameter: gainParameter,
          min: 0,
          max: 1,
          width: 26,
          height: 26,
          stickyPoints: [gainParameterZeroDbNormalized],
          hint: (value) => 'Track gain: ${gainParameterValueToString(value)}',
        ),
        Text(
          'Gain',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
        ),
      ],
    );
  }
}

class _BalanceControl extends StatelessWidget {
  final NodeModel node;

  const _BalanceControl({required this.node});

  @override
  Widget build(BuildContext context) {
    final balanceParameter = ParameterControlBinding.byId(
      node: node,
      portId: UtilityProcessorModel.balancePortId,
      parameterToControlValue: UtilityProcessorModel.parameterValueToPan,
      controlToParameterValue: UtilityProcessorModel.panToParameterValue,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Knob(
          parameter: balanceParameter,
          min: -1,
          max: 1,
          width: 26,
          height: 26,
          type: .pan,
          stickyPoints: [0],
          hint: (value) =>
              'Track balance: ${UtilityProcessorModel.parameterValueToString(UtilityProcessorModel.panToParameterValue(value))}',
        ),
        Text(
          'Pan',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
        ),
      ],
    );
  }
}

class _InvalidUtilityDevice extends StatelessWidget {
  final String name;

  const _InvalidUtilityDevice({required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Center(
        child: Text(
          name,
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ),
    );
  }
}
