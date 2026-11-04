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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migration.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:path/path.dart' as path;

const prealpha2ProjectFileMigration = ProjectFileMigration(
  targetVersion: ProjectFileVersion(
    major: 0,
    minor: 0,
    bugfix: 0,
    extra: 'prealpha.2',
  ),
  migrate: _migrateToPrealpha2,
);

Future<void> _migrateToPrealpha2(
  ProjectJson projectJson,
  String? projectDirectory,
) async {
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
  final nodes = projectJson['processingGraph']['nodes'] as Map<String, dynamic>;
  final retentions = <String, dynamic>{};
  var stateFileNumber = 1;
  for (final node in nodes.values.cast<Map<String, dynamic>>()) {
    final state = node.remove('processorState');
    final parameters = <String, double>{};
    for (final port
        in (node['controlInputPorts'] as List).cast<Map<String, dynamic>>()) {
      final config = port['config'] as Map<String, dynamic>;
      if (config['parameterConfig'] == null) continue;
      final value = port['parameterValue'] ?? port['parameterResetValue'];
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        throw const FormatException('Invalid saved parameter value.');
      }
      parameters['${port['id']}'] = value.toDouble();
    }
    node.remove('isThirdPartyPlugin');
    node['initialParameterValues'] = <String, double>{};
    if ((state == null || state == '') &&
        (node['processor'] == null || parameters.isEmpty)) {
      node.remove('processorStateRetentionId');
      continue;
    }
    if (state != null && state is! String) {
      throw const FormatException('Expected a plugin state string.');
    }
    final bytes = state == null || state == ''
        ? Uint8List(0)
        : _decodeJuceMemoryBlock(state as String);
    // Version 1 snapshots contain a JSON header followed by raw private state.
    // This migration encodes the historical data without using current models.
    final metadata = utf8.encode(
      jsonEncode({'version': 1, 'parameters': parameters}),
    );
    final prefix = ByteData(12)..setUint32(8, metadata.length, Endian.little);
    prefix.buffer.asUint8List().setRange(0, 8, ascii.encode('ANTHST01'));
    if (projectDirectory == null) {
      throw const ProjectDirectoryRequiresDesktopException();
    }
    // These paths belong to the prealpha.2 file format. Write them before the
    // current model and asset store are opened, independently of their APIs.
    final stateNumber = stateFileNumber++;
    final relativePath = 'plugin states/$stateNumber.bin';
    final file = File(
      path.joinAll([projectDirectory, ...relativePath.split('/')]),
    );
    await file.parent.create(recursive: true);
    await file.create(exclusive: true);
    final output = file.openWrite();
    try {
      output.add(prefix.buffer.asUint8List());
      output.add(metadata);
      output.add(bytes);
      await output.flush();
    } finally {
      await output.close();
    }
    final retentionId = 'migrated-plugin-state-$stateNumber';
    retentions[retentionId] = relativePath;
    node['processorStateRetentionId'] = retentionId;
  }
  projectJson['fileRetentions'] = jsonEncode(retentions);
}

// JUCE's legacy MemoryBlock encoding is not standard Base64. It prefixes the
// byte count and encodes six-bit groups starting at the least significant bit.
Uint8List _decodeJuceMemoryBlock(String encoded) {
  const alphabet =
      '.ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+';
  final dot = encoded.indexOf('.');
  if (dot <= 0 || !RegExp(r'^\d+$').hasMatch(encoded.substring(0, dot))) {
    throw const FormatException('Invalid legacy plugin state encoding.');
  }
  final length = int.tryParse(encoded.substring(0, dot));
  final data = encoded.substring(dot + 1);
  if (length == null || data.length != (length * 8 + 5) ~/ 6) {
    throw const FormatException('Invalid legacy plugin state length.');
  }
  final bytes = Uint8List(length);
  for (var index = 0; index < data.length; index++) {
    final value = alphabet.indexOf(data[index]);
    if (value < 0) {
      throw const FormatException('Invalid legacy plugin state character.');
    }
    final bit = index * 6;
    final offset = bit ~/ 8;
    if (offset < length) bytes[offset] |= value << (bit % 8);
    if (bit % 8 > 2 && offset + 1 < length) {
      bytes[offset + 1] |= value >> (8 - bit % 8);
    }
  }
  return bytes;
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
            final savedBaseline = parameter['normalizedVisualBaseline'];
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
          parameter['normalizedVisualBaseline'] = baseline;
        }
      }
    }
  }
}
