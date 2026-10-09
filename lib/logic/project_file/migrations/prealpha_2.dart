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

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migration.dart';
import 'package:anthem/logic/project_file/version.dart';

const prealpha2ProjectFileMigration = ProjectFileMigration(
  targetVersion: ProjectFileVersion(
    major: 0,
    minor: 0,
    bugfix: 0,
    extra: 'prealpha.2',
  ),
  migrate: _migrateToPrealpha2,
);

void _migrateToPrealpha2(ProjectJson projectJson) {
  final sequenceValue = projectJson['sequence'];
  if (sequenceValue is! Map<String, dynamic>) {
    throw const FormatException('Expected sequence to be a JSON object.');
  }

  final arrangementsValue = sequenceValue['arrangements'];
  if (arrangementsValue is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected sequence.arrangements to be a JSON object.',
    );
  }

  if (arrangementsValue.length > 1) {
    throw MultipleArrangementsProjectFileException(
      arrangementCount: arrangementsValue.length,
    );
  }

  if (arrangementsValue.isEmpty) {
    throw const FormatException(
      'Expected the project to contain one arrangement, but found none.',
    );
  }

  final arrangementValue = arrangementsValue.values.single;
  if (arrangementValue is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected the arrangement to be a JSON object.',
    );
  }

  sequenceValue['arrangement'] = arrangementValue;
  sequenceValue.remove('arrangements');
  sequenceValue.remove('arrangementOrder');

  _migrateParameterMetadata(projectJson);
}

void _migrateParameterMetadata(ProjectJson projectJson) {
  final graph = projectJson['processingGraph'];
  if (graph is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected processingGraph to be a JSON object.',
    );
  }
  final nodes = graph['nodes'];
  if (nodes is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected processingGraph.nodes to be a JSON object.',
    );
  }

  for (final node in nodes.values) {
    if (node is! Map<String, dynamic>) {
      throw const FormatException('Expected a processing graph node object.');
    }
    final isThirdPartyPlugin = node['isThirdPartyPlugin'];
    if (isThirdPartyPlugin is! bool) {
      throw const FormatException(
        'Expected node.isThirdPartyPlugin to be a bool.',
      );
    }
    final processor = node['processor'];
    if (processor != null &&
        (processor is! Map<String, dynamic> || processor.length != 1)) {
      throw const FormatException('Expected one processor type or null.');
    }
    final isNativeProcessor = !isThirdPartyPlugin && processor != null;
    // These IDs describe the historical file schema, independently of future
    // changes to processor implementations.
    final panPortId = switch (processor) {
      {'UtilityProcessorModel': _} => 3,
      {'BalanceProcessorModel': _} => 2,
      _ => null,
    };

    for (final group in const [
      'audioInputPorts',
      'audioOutputPorts',
      'eventInputPorts',
      'eventOutputPorts',
      'controlInputPorts',
      'controlOutputPorts',
    ]) {
      final ports = node[group];
      if (ports is! List) {
        throw FormatException('Expected node.$group to be a JSON array.');
      }
      for (final port in ports) {
        if (port is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected a processing graph port object.',
          );
        }
        final config = port['config'];
        if (config is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected port.config to be a JSON object.',
          );
        }
        final parameter = config['parameterConfig'];
        if (parameter != null && parameter is! Map<String, dynamic>) {
          throw const FormatException(
            'Expected a parameter config object or null.',
          );
        }

        num baseline = 0.0;
        if (parameter is Map<String, dynamic>) {
          final oldDefault = parameter.remove('defaultValue');
          if (oldDefault is! num) {
            throw const FormatException(
              'Expected parameter.defaultValue to be a number.',
            );
          }
          // The old default also defined reset behavior. Preserve it as
          // instance state; native factory defaults are supplied by discovery.
          port['parameterResetValue'] = oldDefault;
          if (isNativeProcessor) {
            parameter.remove('factoryDefaultValue');
          } else {
            parameter['factoryDefaultValue'] = oldDefault;
          }

          if (parameter.containsKey('normalizedVisualBaseline')) {
            final savedBaseline = parameter.remove('normalizedVisualBaseline');
            if (savedBaseline is! num ||
                !savedBaseline.isFinite ||
                savedBaseline < 0 ||
                savedBaseline > 1) {
              throw const FormatException(
                'Parameter visual baseline must be in [0, 1].',
              );
            }
            baseline = savedBaseline;
          } else if (isNativeProcessor &&
              group == 'controlInputPorts' &&
              port['id'] == panPortId) {
            baseline = 0.5;
          }
        }
        port['presentation'] = {'normalizedVisualBaseline': baseline};
      }
    }
  }
}
