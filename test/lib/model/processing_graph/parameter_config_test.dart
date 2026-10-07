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
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/balance.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'visual baseline is independent of display format and reset default',
    () {
      for (final mode in ParameterDisplayMode.values) {
        for (final baseline in [0.0, 0.25, 0.5, 1.0]) {
          final config = ParameterConfigModel(
            id: 1,
            defaultValue: 0.75,
            displayMode: mode,
            normalizedVisualBaseline: baseline,
          );
          final restored = ParameterConfigModel.fromJson(config.toJson());
          expect(restored.normalizedVisualBaseline, baseline);
          expect(restored.defaultValue, 0.75);
          expect(restored.displayMode, mode);
          expect(
            config.toJson(forEngine: true, forProjectFile: false),
            isNot(contains('normalizedVisualBaseline')),
          );
        }
      }
    },
  );

  test('missing visual baseline defaults to minimum', () {
    expect(
      ParameterConfigModel.fromJson({
        'id': 1,
        'defaultValue': 0.75,
        'displayMode': 'pluginText',
      }).normalizedVisualBaseline,
      0,
    );
  });

  test('visual baseline validates saved values', () {
    for (final value in [
      -0.1,
      1.1,
      double.nan,
      double.infinity,
      'center',
      null,
    ]) {
      expect(
        () => ParameterConfigModel.fromJson({
          'id': 1,
          'defaultValue': 0.75,
          'normalizedVisualBaseline': value,
        }),
        throwsFormatException,
      );
    }
  });

  test('visual baseline changes stay in the UI', () {
    final config = ParameterConfigModel(id: 1, defaultValue: 0.75);
    config.isTopLevelModel = true;
    config.setParentPropertiesOnChildren();
    final changes = <ModelChangeEvent>[];
    config.addRawFieldChangedListener(changes.add);
    config.normalizedVisualBaseline = 0.25;
    expect(changes, hasLength(1));
    expect(changes.single.sendToEngine, isFalse);
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
    test('native pan baseline survives new and legacy files ($utility)', () {
      final node = makeNode();
      expect(
        node
            .getInputPortById(NodePortDataType.control, panId)
            .config
            .parameterConfig!
            .normalizedVisualBaseline,
        0.5,
      );
      final json = node.toJson();
      final portJson = (json['controlInputPorts'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((port) => port['id'] == panId);
      final parameter =
          portJson['config']['parameterConfig'] as Map<String, dynamic>;
      expect(
        NodeModel.fromJson(json)
            .getInputPortById(NodePortDataType.control, panId)
            .config
            .parameterConfig!
            .normalizedVisualBaseline,
        0.5,
      );
      parameter.remove('normalizedVisualBaseline');
      expect(
        NodeModel.fromJson(json)
            .getInputPortById(NodePortDataType.control, panId)
            .config
            .parameterConfig!
            .normalizedVisualBaseline,
        0.5,
      );
      parameter['normalizedVisualBaseline'] = 0.0;
      expect(
        NodeModel.fromJson(json)
            .getInputPortById(NodePortDataType.control, panId)
            .config
            .parameterConfig!
            .normalizedVisualBaseline,
        0.0,
      );
    });
  }
}
