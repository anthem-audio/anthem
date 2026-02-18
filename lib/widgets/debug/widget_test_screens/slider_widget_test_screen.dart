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
import 'package:anthem/widgets/basic/controls/slider.dart';
import 'package:flutter/widgets.dart';

class SliderWidgetTestScreen extends StatefulWidget {
  const SliderWidgetTestScreen({super.key});

  @override
  State<SliderWidgetTestScreen> createState() => _SliderWidgetTestScreenState();
}

class _SliderWidgetTestScreenState extends State<SliderWidgetTestScreen> {
  final List<double> verticalValues = [0.0, 0.28, 0.45, 0.62, 1.0];
  final List<double> horizontalValues = [0.0, 0.33, 0.58, 0.8, 1.0];
  double panValue = 0.0;

  String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Vertical sliders',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AnthemTheme.panel.backgroundDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AnthemTheme.panel.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (int i = 0; i < verticalValues.length; i++)
                SizedBox(
                  width: 18,
                  height: 106,
                  child: Slider(
                    width: 18,
                    height: 106,
                    axis: SliderAxis.vertical,
                    value: verticalValues[i],
                    min: 0,
                    max: 1,
                    hoverHintOverride: _formatPercent,
                    hint: _formatPercent,
                    onValueChanged: (value) {
                      setState(() {
                        verticalValues[i] = value.clamp(0, 1);
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Horizontal sliders',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AnthemTheme.panel.backgroundDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AnthemTheme.panel.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (int i = 0; i < horizontalValues.length; i++)
                SizedBox(
                  width: 150,
                  height: 16,
                  child: Slider(
                    width: 150,
                    height: 16,
                    axis: SliderAxis.horizontal,
                    value: horizontalValues[i],
                    min: 0,
                    max: 1,
                    hoverHintOverride: _formatPercent,
                    hint: _formatPercent,
                    onValueChanged: (value) {
                      setState(() {
                        horizontalValues[i] = value.clamp(0, 1);
                      });
                    },
                  ),
                ),
              SizedBox(
                width: 150,
                height: 16,
                child: Slider(
                  width: 150,
                  height: 16,
                  axis: SliderAxis.horizontal,
                  type: SliderType.pan,
                  value: panValue,
                  min: -1,
                  max: 1,
                  stickyPoints: const [0],
                  onValueChanged: (value) {
                    setState(() {
                      panValue = value.clamp(-1, 1);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          height: 30,
          child: Button(
            text: 'Reset values',
            onPress: () {
              setState(() {
                verticalValues
                  ..clear()
                  ..addAll([0.0, 0.28, 0.45, 0.62, 1.0]);
                horizontalValues
                  ..clear()
                  ..addAll([0.0, 0.33, 0.58, 0.8, 1.0]);
                panValue = 0.0;
              });
            },
          ),
        ),
      ],
    );
  }
}
