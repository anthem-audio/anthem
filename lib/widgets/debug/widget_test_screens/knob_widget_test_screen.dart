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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:flutter/widgets.dart';

class KnobWidgetTestScreen extends StatefulWidget {
  const KnobWidgetTestScreen({super.key});

  @override
  State<KnobWidgetTestScreen> createState() => _KnobWidgetTestScreenState();
}

class _KnobWidgetTestScreenState extends State<KnobWidgetTestScreen> {
  double gain = 0.5;
  double pan = 0;
  double drive = 6;

  String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';
  String _formatPan(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    Widget buildKnob({
      required String label,
      required double value,
      required KnobType type,
      required double min,
      required double max,
      required List<double> stickyPoints,
      required void Function(double value) onChanged,
      required String Function(double value) formatter,
    }) {
      return SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            Text(
              label,
              style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
            ),
            SizedBox(
              width: 54,
              height: 54,
              child: Knob(
                width: 54,
                height: 54,
                type: type,
                value: value,
                min: min,
                max: max,
                stickyPoints: stickyPoints,
                hoverHintOverride: formatter,
                hint: formatter,
                onValueChanged: onChanged,
              ),
            ),
            Text(
              formatter(value),
              style: TextStyle(color: AnthemTheme.text.main, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 16,
          children: [
            buildKnob(
              label: 'Gain',
              value: gain,
              type: KnobType.normal,
              min: 0,
              max: 1,
              stickyPoints: [0.5],
              formatter: _formatPercent,
              onChanged: (value) {
                setState(() {
                  gain = value.clamp(0, 1);
                });
              },
            ),
            buildKnob(
              label: 'Pan',
              value: pan,
              type: KnobType.pan,
              min: -1,
              max: 1,
              stickyPoints: [0],
              formatter: _formatPan,
              onChanged: (value) {
                setState(() {
                  pan = value.clamp(-1, 1);
                });
              },
            ),
            buildKnob(
              label: 'Drive',
              value: drive,
              type: KnobType.normal,
              min: 0,
              max: 12,
              stickyPoints: [6],
              formatter: (value) => value.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  drive = value.clamp(0, 12);
                });
              },
            ),
          ],
        ),
        SizedBox(
          width: 150,
          height: 30,
          child: Button(
            text: 'Reset values',
            onPress: () {
              setState(() {
                gain = 0.5;
                pan = 0;
                drive = 6;
              });
            },
          ),
        ),
      ],
    );
  }
}
