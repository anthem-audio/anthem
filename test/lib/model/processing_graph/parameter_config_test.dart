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

import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached descriptions and values round-trip independently of reset overrides', () {
    for (final mode in ParameterDisplayMode.values) {
      for (final baseline in [0.0, 0.25, 0.5, 1.0]) {
        final port = NodePortModel(
          id: 1,
          nodeId: 2,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: 1,
              factoryDefaultValue: 0.75,
              displayMode: mode,
              normalizedVisualBaseline: baseline,
            ),
          ),
          initialParameterValue: 0.1,
          parameterResetValue: 0.2,
        );
        final restored = NodePortModel.fromJson(port.toJson());
        expect(
          restored.config.parameterConfig!.normalizedVisualBaseline,
          baseline,
        );
        expect(restored.config.parameterConfig!.displayMode, mode);
        expect(restored.config.parameterConfig!.factoryDefaultValue, 0.75);
        expect(restored.parameterValue, 0.1);
        expect(restored.parameterResetTarget, 0.2);
        final engineJson = port.toJson(forEngine: true, forProjectFile: false);
        expect(engineJson, isNot(contains('parameterValue')));
        expect(engineJson, isNot(contains('parameterResetValue')));
        expect(port.toJson(), isNot(contains('presentation')));
        expect(port.toJson(), isNot(contains('isAvailable')));
        restored.pendingParameterValue = 0.9;
        expect(restored.parameterValueOrResetTarget, 0.1);
        restored.parameterValue = null;
        expect(restored.parameterValueOrResetTarget, 0.2);
        restored.parameterResetValue = null;
        expect(restored.parameterValueOrResetTarget, 0.75);
      }
    }
  });

  test('pending endpoints need no parameter description to round-trip', () {
    final port = NodePortModel(
      id: 1,
      nodeId: 2,
      config: NodePortConfigModel(dataType: NodePortDataType.control),
    );
    final restored = NodePortModel.fromJson(port.toJson());
    expect(restored.config.parameterConfig, isNull);
    expect(restored.parameterValue, isNull);
    expect(restored.parameterResetValue, isNull);
  });

  test(
    'project reset overrides remain excluded from engine synchronization',
    () {
      final port = NodePortModel(
        id: 1,
        nodeId: 2,
        config: NodePortConfigModel(dataType: NodePortDataType.control),
      );
      port.isTopLevelModel = true;
      port.setParentPropertiesOnChildren();
      final changes = <ModelChangeEvent>[];
      port.addRawFieldChangedListener(changes.add);
      port.parameterResetValue = 0.2;
      expect(changes.single.sendToEngine, isFalse);
    },
  );
}
