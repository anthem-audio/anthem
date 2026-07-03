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
  final List<double> backgroundlessValues = [0.15, 0.5, 0.85];
  final List<double> noLockValues = [0.18, 0.46, 0.72];
  double panValue = 0.0;
  double noLockVerticalValue = 0.38;
  double noLockBackgroundlessValue = 0.56;
  double noLockBackgroundlessVerticalValue = 0.72;
  double noLockPanValue = 0.0;

  String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

  Widget _buildGroup({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          title,
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AnthemTheme.panel.backgroundDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AnthemTheme.panel.border),
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _buildGroup(
              title: 'Vertical sliders',
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
            _buildGroup(
              title: 'Horizontal sliders',
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
            _buildGroup(
              title: 'Backgroundless sliders',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      for (int i = 0; i < backgroundlessValues.length; i++)
                        SizedBox(
                          width: 18,
                          height: 106,
                          child: Slider(
                            width: 18,
                            height: 106,
                            axis: SliderAxis.vertical,
                            value: backgroundlessValues[i],
                            min: 0,
                            max: 1,
                            noBackground: true,
                            hoverHintOverride: _formatPercent,
                            hint: _formatPercent,
                            onValueChanged: (value) {
                              setState(() {
                                backgroundlessValues[i] = value.clamp(0, 1);
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    width: 150,
                    height: 16,
                    child: Slider(
                      width: 150,
                      height: 16,
                      axis: SliderAxis.horizontal,
                      value: backgroundlessValues[1],
                      min: 0,
                      max: 1,
                      noBackground: true,
                      hoverHintOverride: _formatPercent,
                      hint: _formatPercent,
                      onValueChanged: (value) {
                        setState(() {
                          backgroundlessValues[1] = value.clamp(0, 1);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildGroup(
              title: 'No-lock sliders',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 12,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      for (int i = 0; i < noLockValues.length; i++)
                        SizedBox(
                          width: 150,
                          height: 16,
                          child: Slider(
                            width: 150,
                            height: 16,
                            axis: SliderAxis.horizontal,
                            value: noLockValues[i],
                            min: 0,
                            max: 1,
                            usePointerLock: false,
                            hoverHintOverride: _formatPercent,
                            hint: _formatPercent,
                            onValueChanged: (value) {
                              setState(() {
                                noLockValues[i] = value.clamp(0, 1);
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
                          value: noLockPanValue,
                          min: -1,
                          max: 1,
                          stickyPoints: const [0],
                          usePointerLock: false,
                          onValueChanged: (value) {
                            setState(() {
                              noLockPanValue = value.clamp(-1, 1);
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
                          value: noLockBackgroundlessValue,
                          min: 0,
                          max: 1,
                          noBackground: true,
                          usePointerLock: false,
                          hoverHintOverride: _formatPercent,
                          hint: _formatPercent,
                          onValueChanged: (value) {
                            setState(() {
                              noLockBackgroundlessValue = value.clamp(0, 1);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 18,
                    height: 106,
                    child: Slider(
                      width: 18,
                      height: 106,
                      axis: SliderAxis.vertical,
                      value: noLockVerticalValue,
                      min: 0,
                      max: 1,
                      usePointerLock: false,
                      hoverHintOverride: _formatPercent,
                      hint: _formatPercent,
                      onValueChanged: (value) {
                        setState(() {
                          noLockVerticalValue = value.clamp(0, 1);
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 18,
                    height: 106,
                    child: Slider(
                      width: 18,
                      height: 106,
                      axis: SliderAxis.vertical,
                      value: noLockBackgroundlessVerticalValue,
                      min: 0,
                      max: 1,
                      noBackground: true,
                      usePointerLock: false,
                      hoverHintOverride: _formatPercent,
                      hint: _formatPercent,
                      onValueChanged: (value) {
                        setState(() {
                          noLockBackgroundlessVerticalValue = value.clamp(0, 1);
                        });
                      },
                    ),
                  ),
                ],
              ),
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
                verticalValues
                  ..clear()
                  ..addAll([0.0, 0.28, 0.45, 0.62, 1.0]);
                horizontalValues
                  ..clear()
                  ..addAll([0.0, 0.33, 0.58, 0.8, 1.0]);
                backgroundlessValues
                  ..clear()
                  ..addAll([0.15, 0.5, 0.85]);
                noLockValues
                  ..clear()
                  ..addAll([0.18, 0.46, 0.72]);
                panValue = 0.0;
                noLockVerticalValue = 0.38;
                noLockBackgroundlessValue = 0.56;
                noLockBackgroundlessVerticalValue = 0.72;
                noLockPanValue = 0.0;
              });
            },
          ),
        ),
      ],
    );
  }
}
