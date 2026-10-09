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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/parameter_presentation.dart';
import 'package:anthem/model/processing_graph/processors/balance.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation, factory default, instance value and reset target are independent', () {
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
            ),
          ),
          presentation: ParameterPresentationModel(
            normalizedVisualBaseline: baseline,
          ),
          initialParameterValue: 0.1,
          parameterResetValue: 0.2,
        );
        final restored = NodePortModel.fromJson(port.toJson());
        expect(restored.presentation.normalizedVisualBaseline, baseline);
        expect(restored.parameterValue, 0.1);
        expect(restored.parameterResetTarget, 0.2);
        expect(restored.config.parameterConfig!.factoryDefaultValue, 0.75);
        final engineJson = port.toJson(forEngine: true, forProjectFile: false);
        expect(engineJson, isNot(contains('presentation')));
        expect(engineJson, isNot(contains('parameterResetValue')));
        expect(engineJson, isNot(contains('resolvedConnections')));
        expect(port.toJson(), isNot(contains('resolvedConnections')));
        expect(port.toJson(), isNot(contains('isAvailable')));
      }
    }
  });

  test('port import requires current presentation metadata', () {
    final port = NodePortModel(
      id: 1,
      nodeId: 2,
      config: NodePortConfigModel(dataType: NodePortDataType.control),
    );
    final json = port.toJson()..remove('presentation');
    expect(() => NodePortModel.fromJson(json), throwsA(isA<TypeError>()));
  });

  test('presentation validates saved values', () {
    for (final value in [
      -0.1,
      1.1,
      double.nan,
      double.infinity,
      'center',
      null,
    ]) {
      expect(
        () => ParameterPresentationModel.fromJson({
          'normalizedVisualBaseline': value,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ParameterPresentationModel.fromJson({}),
      throwsFormatException,
    );
  });

  test('presentation changes stay in the UI', () {
    final port = NodePortModel(
      id: 1,
      nodeId: 2,
      config: NodePortConfigModel(dataType: NodePortDataType.control),
    );
    port.isTopLevelModel = true;
    port.setParentPropertiesOnChildren();
    final changes = <ModelChangeEvent>[];
    port.addRawFieldChangedListener(changes.add);
    port.presentation.normalizedVisualBaseline = 0.25;
    port.parameterResetValue = 0.2;
    expect(changes, hasLength(2));
    expect(changes.every((change) => !change.sendToEngine), isTrue);
  });

  for (final utility in [true, false]) {
    NodeModel makeNode() {
      var id = 0;
      final allocator = ProjectEntityIdAllocator.test(() => ++id);
      return utility
          ? UtilityProcessorModel.create(idAllocator: allocator).createNode()
          : BalanceProcessorModel.create(idAllocator: allocator).createNode();
    }

    final panId = utility
        ? UtilityProcessorModel.balancePortId
        : BalanceProcessorModel.balancePortId;
    test(
      'native pan presentation round-trips in the current schema ($utility)',
      () {
        final node = makeNode();
        expect(
          node
              .getInputPortById(NodePortDataType.control, panId)
              .presentation
              .normalizedVisualBaseline,
          0.5,
        );
        final json = node.toJson();
        final restored = NodeModel.fromJson(json);
        expect(
          restored
              .getInputPortById(NodePortDataType.control, panId)
              .presentation
              .normalizedVisualBaseline,
          0.5,
        );
        node
                .getInputPortById(NodePortDataType.control, panId)
                .presentation
                .normalizedVisualBaseline =
            0.0;
        expect(
          NodeModel.fromJson(node.toJson())
              .getInputPortById(NodePortDataType.control, panId)
              .presentation
              .normalizedVisualBaseline,
          0.0,
        );
      },
    );
  }
}
