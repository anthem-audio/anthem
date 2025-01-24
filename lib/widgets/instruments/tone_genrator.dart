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

import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/knob.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class ToneGenerator extends StatefulWidget {
  final NodeModel node;

  const ToneGenerator({super.key, required this.node});

  @override
  State<ToneGenerator> createState() => _ToneGeneratorState();
}

class _ToneGeneratorState extends State<ToneGenerator> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: Theme.panel.accent,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Observer(builder: (context) {
                final value = widget.node
                        .getPortById(
                            ToneGeneratorProcessorModel.frequencyPortId)
                        .parameterValue ??
                    440;

                return Knob(
                  value: value,
                  min: 20,
                  max: 1200,
                  width: 26,
                  height: 26,
                  onValueChanged: (newValue) {
                    widget.node
                        .getPortById(
                            ToneGeneratorProcessorModel.frequencyPortId)
                        .parameterValue = newValue;
                  },
                );
              }),
              Text(
                'Pitch',
                style: TextStyle(
                  color: Theme.text.main,
                ),
              ),
              Observer(builder: (context) {
                final value = widget.node
                        .getPortById(
                            ToneGeneratorProcessorModel.amplitudePortId)
                        .parameterValue ??
                    0.125;

                return Knob(
                  value: value,
                  min: 0,
                  max: 1,
                  width: 26,
                  height: 26,
                  onValueChanged: (value) {
                    widget.node
                        .getPortById(
                            ToneGeneratorProcessorModel.amplitudePortId)
                        .parameterValue = value;
                  },
                );
              }),
              Text(
                'Amp',
                style: TextStyle(
                  color: Theme.text.main,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
