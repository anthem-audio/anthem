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
import 'package:anthem/helpers/parameter_display.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatParameterDisplayValue', () {
    test('formats percent parameters by default', () {
      final port = _parameterPort(defaultValue: 0.5);

      expect(formatParameterDisplayValue(port, 0.25), '25.0%');
    });

    test('formats gain parameters as dB', () {
      final port = _parameterPort(
        defaultValue: gainParameterZeroDbNormalized,
        displayMode: ParameterDisplayMode.gainDb,
      );

      expect(
        formatParameterDisplayValue(port, gainParameterZeroDbNormalized),
        '0 dB',
      );
    });

    test('formats pan parameters', () {
      final port = _parameterPort(
        defaultValue: 0.5,
        displayMode: ParameterDisplayMode.pan,
      );

      expect(formatParameterDisplayValue(port, 0.5), 'Center');
      expect(formatParameterDisplayValue(port, 0.25), '50% L');
      expect(formatParameterDisplayValue(port, 0.75), '50% R');
    });

    test('formats plugin-provided text with unit labels', () {
      final port = _parameterPort(
        defaultValue: 0.5,
        displayMode: ParameterDisplayMode.pluginText,
        unitLabel: 'Hz',
        displayText: '440',
      );

      expect(formatParameterDisplayValue(port, 0.5), '440 Hz');
    });

    test('falls back to percent when plugin text is missing', () {
      final port = _parameterPort(
        defaultValue: 0.5,
        displayMode: ParameterDisplayMode.pluginText,
        unitLabel: 'Hz',
      );

      expect(formatParameterDisplayValue(port, 0.5), '50.0%');
    });
  });
}

NodePortModel _parameterPort({
  required double defaultValue,
  ParameterDisplayMode? displayMode,
  String? unitLabel,
  String? displayText,
}) {
  return NodePortModel(
    id: 1,
    nodeId: 1,
    config: NodePortConfigModel(
      dataType: NodePortDataType.control,
      parameterConfig: ParameterConfigModel(
        id: 1,
        defaultValue: defaultValue,
        displayMode: displayMode,
        unitLabel: unitLabel,
      ),
    ),
    parameterDisplayText: displayText,
  );
}
