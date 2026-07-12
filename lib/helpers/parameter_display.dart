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
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';

String formatParameterDisplayValue(NodePortModel port, double value) {
  final parameterConfig = port.config.parameterConfig;

  return switch (parameterConfig?.displayMode) {
    ParameterDisplayMode.gainDb => gainParameterValueToString(value),
    ParameterDisplayMode.pan => formatPanParameterValue(value),
    ParameterDisplayMode.pluginText => _formatPluginText(
      text: port.parameterDisplayText,
      unitLabel: parameterConfig?.unitLabel,
      fallbackValue: value,
    ),
    ParameterDisplayMode.percent || null => formatPercentParameterValue(value),
  };
}

String formatPercentParameterValue(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}

String formatPanParameterValue(double value) {
  final pan = value * 2.0 - 1.0;

  if (pan.abs() < 0.000001) {
    return 'Center';
  }

  return '${(pan * 100).abs().toStringAsFixed(0)}%${pan < 0 ? ' L' : ' R'}';
}

String _formatPluginText({
  required String? text,
  required String? unitLabel,
  required double fallbackValue,
}) {
  final displayText = text?.trim();
  if (displayText == null || displayText.isEmpty) {
    return formatPercentParameterValue(fallbackValue);
  }

  final unit = unitLabel?.trim();
  if (unit == null || unit.isEmpty) {
    return displayText;
  }

  if (displayText.toLowerCase().endsWith(unit.toLowerCase())) {
    return displayText;
  }

  return '$displayText $unit';
}
