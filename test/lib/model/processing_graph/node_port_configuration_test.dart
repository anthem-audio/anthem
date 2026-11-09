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

import 'package:anthem/engine_api/messages/messages.dart'
    show ProcessingGraphNodePortConfiguration, ProcessingGraphPortConfiguration;
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructed and deserialized nodes keep their processor instance', () {
    final original = NodeModel(id: 1, processor: GainProcessorModel(nodeId: 1));
    final restored = NodeModel.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());

    for (final node in [original, restored]) {
      final processor = node.processor;
      expect(
        () => node.processor = GainProcessorModel(nodeId: 1),
        throwsA(isA<Error>()),
      );
      expect(node.processor, same(processor));
    }
  });

  test('metadata refresh preserves port state without a routing change', () {
    final node = NodeModel(id: 1, processor: GainProcessorModel(nodeId: 1));
    expect(
      node.applyPortConfiguration(
        _configuration(
          audioInputs: [
            ProcessingGraphPortConfiguration(id: 10, channelCount: 2),
          ],
          controls: [
            ProcessingGraphPortConfiguration(
              id: 100,
              parameterDefaultValue: 0.2,
            ),
          ],
        ),
      ),
      isTrue,
    );
    final audio = node.audioInputPorts.single;
    final port = node.controlInputPorts.single;
    final config = port.config;
    final parameter = config.parameterConfig!;
    port.parameterValue = 0.7;
    port.parameterResetValue = 0.4;
    port.connections.add(99);

    expect(
      node.applyPortConfiguration(
        _configuration(
          audioInputs: [
            ProcessingGraphPortConfiguration(
              id: 10,
              name: 'Four-channel input',
              channelCount: 4,
            ),
          ],
          controls: [
            ProcessingGraphPortConfiguration(
              id: 100,
              name: 'Balance',
              parameterDefaultValue: 0.6,
              parameterDisplayMode: 'pan',
              parameterUnitLabel: '%',
              parameterNormalizedVisualBaseline: 0.5,
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(node.audioInputPorts.single, same(audio));
    expect(audio.config.name, 'Four-channel input');
    expect(audio.config.channelCount, 4);
    expect(node.controlInputPorts.single, same(port));
    expect(port.config, same(config));
    expect(config.parameterConfig, same(parameter));
    expect(config.name, 'Balance');
    expect(parameter.factoryDefaultValue, 0.6);
    expect(parameter.displayMode, ParameterDisplayMode.pan);
    expect(parameter.unitLabel, '%');
    expect(parameter.normalizedVisualBaseline, 0.5);
    expect(port.parameterValue, 0.7);
    expect(port.parameterResetTarget, 0.4);
    expect(port.connections, [99]);
  });

  test('repeated reports emit no model changes or routing changes', () {
    final node = NodeModel(id: 1, processor: GainProcessorModel(nodeId: 1));
    node.isTopLevelModel = true;
    node.setParentPropertiesOnChildren();
    final configuration = _configuration(
      audioInputs: [ProcessingGraphPortConfiguration(id: 10, channelCount: 2)],
      controls: [
        ProcessingGraphPortConfiguration(
          id: 100,
          parameterDefaultValue: 0.2,
          parameterDisplayMode: 'gainDb',
          parameterUnitLabel: 'dB',
        ),
      ],
    );
    expect(node.applyPortConfiguration(configuration), isTrue);
    final port = node.controlInputPorts.single;
    final parameter = port.config.parameterConfig;
    final changes = <ModelChangeEvent>[];
    node.addRawFieldChangedListener(changes.add);
    expect(node.applyPortConfiguration(configuration), isFalse);
    expect(node.controlInputPorts.single, same(port));
    expect(port.config.parameterConfig, same(parameter));
    expect(changes, isEmpty);
  });

  test(
    'port disappearance, recovery and reordering preserve saved objects',
    () {
      final node = NodeModel(id: 1, processor: GainProcessorModel(nodeId: 1));
      ProcessingGraphNodePortConfiguration ports(List<int> ids) =>
          _configuration(
            controls: [
              for (final id in ids)
                ProcessingGraphPortConfiguration(
                  id: id,
                  parameterDefaultValue: 0.5,
                ),
            ],
          );
      expect(node.applyPortConfiguration(ports([100, 101])), isTrue);
      final first = node.controlInputPorts[0];
      final second = node.controlInputPorts[1];
      first.parameterValue = 0.7;
      first.parameterResetValue = 0.4;
      first.connections.add(99);

      expect(node.applyPortConfiguration(ports([101])), isTrue);
      expect(node.controlInputPorts, [second, first]);
      expect(first.isAvailable, isFalse);
      expect(first.config.parameterConfig!.factoryDefaultValue, 0.5);
      expect(node.applyPortConfiguration(ports([101])), isFalse);

      expect(node.applyPortConfiguration(ports([100, 101])), isTrue);
      expect(node.controlInputPorts, [first, second]);
      expect(first.isAvailable, isTrue);
      expect(first.parameterValue, 0.7);
      expect(first.parameterResetTarget, 0.4);
      expect(first.connections, [99]);

      expect(node.applyPortConfiguration(ports([101, 100])), isTrue);
      expect(node.controlInputPorts, [second, first]);
      expect(node.applyPortConfiguration(ports([101, 100])), isFalse);
    },
  );
}

ProcessingGraphNodePortConfiguration _configuration({
  List<ProcessingGraphPortConfiguration> audioInputs = const [],
  List<ProcessingGraphPortConfiguration> controls = const [],
}) => ProcessingGraphNodePortConfiguration(
  audioInputPorts: audioInputs,
  audioOutputPorts: [],
  eventInputPorts: [],
  eventOutputPorts: [],
  controlInputPorts: controls,
  controlOutputPorts: [],
);
