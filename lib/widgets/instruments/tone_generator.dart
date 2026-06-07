/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:flutter/widgets.dart';

class ToneGenerator extends StatefulWidget {
  final NodeModel node;

  const ToneGenerator({super.key, required this.node});

  @override
  State<ToneGenerator> createState() => _ToneGeneratorState();
}

class _ToneGeneratorState extends State<ToneGenerator> {
  @override
  Widget build(BuildContext context) {
    final frequencyParameter = ParameterUiBinding.byId(
      node: widget.node,
      portId: ToneGeneratorProcessorModel.frequencyPortId,
      parameterToUiValue: ToneGeneratorProcessorModel.parameterValueToFrequency,
      uiToParameterValue: ToneGeneratorProcessorModel.frequencyToParameterValue,
    );
    final amplitudeParameter = ParameterUiBinding.byId(
      node: widget.node,
      portId: ToneGeneratorProcessorModel.amplitudePortId,
    );

    return SizedBox(
      width: 92,
      child: Center(
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Knob(
                parameter: frequencyParameter,
                min: 20,
                max: 1200,
                width: 26,
                height: 26,
              ),
              Text('Pitch', style: TextStyle(color: AnthemTheme.text.main)),
              Knob(
                parameter: amplitudeParameter,
                min: 0,
                max: 1,
                width: 26,
                height: 26,
              ),
              Text('Amp', style: TextStyle(color: AnthemTheme.text.main)),
            ],
          ),
        ),
      ),
    );
  }
}
