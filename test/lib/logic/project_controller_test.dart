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

import 'package:anthem/model/processing_graph/parameter_presentation.dart';

import 'dart:async';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProcessingGraphApi extends Fake implements ProcessingGraphApi {
  final calls = <String>[];
  var publishCallCount = 0;
  var initializeNodesCallCount = 0;
  var didInitialize = true;
  var results = <ProcessingGraphNodeInitializationResult>[];
  Completer<void>? publishCompleter;

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async {
    calls.add('initialize');
    initializeNodesCallCount++;
    return ProcessingGraphNodeInitialization(
      didInitialize: didInitialize,
      results: results,
    );
  }

  @override
  Future<void> publish() async {
    calls.add('publish');
    publishCallCount++;

    final completer = publishCompleter;
    if (completer != null) {
      await completer.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectModel project;
  late ProjectViewModel viewModel;
  late ProjectController controller;

  setUp(() {
    project = ProjectModel.create();
    viewModel = ProjectViewModel();
    controller = ProjectController(project, viewModel);
    ServiceRegistry.initializeProject(project);
  });

  tearDown(() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  });

  group('editor and transport selection', () {
    test('setActivePattern updates active pattern and transport id', () {
      final pattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(project.allocateId),
        name: 'Lead',
      );
      project.sequence.patterns[pattern.id] = pattern;

      controller.setActivePattern(pattern.id);

      expect(project.sequence.activePatternID, equals(pattern.id));
      expect(project.sequence.activeTransportSequenceID, equals(pattern.id));
    });

    test('setActiveEditor maps editor selection to panel selection', () {
      controller.setActiveEditor(editor: EditorKind.pianoRoll);
      expect(viewModel.selectedEditor, equals(EditorKind.pianoRoll));
      expect(viewModel.activePanel, equals(PanelKind.pianoRoll));

      controller.setActiveEditor(editor: EditorKind.deviceRack);
      expect(viewModel.activePanel, equals(PanelKind.deviceRack));

      controller.setActiveEditor(editor: EditorKind.mixer);
      expect(viewModel.activePanel, equals(PanelKind.mixer));
    });

    test('openPatternInPianoRoll switches editor and activates pattern', () {
      final pattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(project.allocateId),
        name: 'Bass',
      );
      project.sequence.patterns[pattern.id] = pattern;

      controller.openPatternInPianoRoll(pattern.id);

      expect(viewModel.selectedEditor, equals(EditorKind.pianoRoll));
      expect(viewModel.activePanel, equals(PanelKind.pianoRoll));
      expect(project.sequence.activePatternID, equals(pattern.id));
    });

    test('openPatternInPianoRoll is a no-op for a missing pattern', () {
      viewModel.selectedEditor = EditorKind.mixer;
      viewModel.activePanel = PanelKind.mixer;
      project.sequence.activePatternID = null;

      controller.openPatternInPianoRoll(-1);

      expect(viewModel.selectedEditor, equals(EditorKind.mixer));
      expect(viewModel.activePanel, equals(PanelKind.mixer));
      expect(project.sequence.activePatternID, isNull);
    });
  });

  group('processing graph', () {
    test(
      'publishProcessingGraph initializes nodes before publishing',
      () async {
        final processingGraphApi = _RecordingProcessingGraphApi();
        project.engine.processingGraphApi = processingGraphApi;

        await controller.publishProcessingGraph();

        expect(processingGraphApi.initializeNodesCallCount, equals(1));
        expect(processingGraphApi.publishCallCount, equals(1));
        expect(
          processingGraphApi.calls,
          orderedEquals(['initialize', 'publish']),
        );
      },
    );

    test(
      'publishProcessingGraph skips publish when initialization did not run',
      () async {
        final processingGraphApi = _RecordingProcessingGraphApi()
          ..didInitialize = false;
        project.engine.processingGraphApi = processingGraphApi;

        await controller.publishProcessingGraph();

        expect(processingGraphApi.initializeNodesCallCount, equals(1));
        expect(processingGraphApi.publishCallCount, equals(0));
        expect(processingGraphApi.calls, orderedEquals(['initialize']));
      },
    );

    test(
      'publishProcessingGraph coalesces queued publishes while in progress',
      () async {
        final processingGraphApi = _RecordingProcessingGraphApi();
        final publishCompleter = Completer<void>();
        processingGraphApi.publishCompleter = publishCompleter;
        project.engine.processingGraphApi = processingGraphApi;

        final firstPublish = controller.publishProcessingGraph();
        await _flushMicrotasks();

        final secondPublish = controller.publishProcessingGraph();
        await _flushMicrotasks();

        final thirdPublish = controller.publishProcessingGraph();
        await _flushMicrotasks();

        expect(
          processingGraphApi.calls,
          orderedEquals(['initialize', 'publish']),
        );

        publishCompleter.complete();
        processingGraphApi.publishCompleter = null;

        await firstPublish;
        await secondPublish;
        await thirdPublish;

        expect(
          processingGraphApi.calls,
          orderedEquals(['initialize', 'publish', 'initialize', 'publish']),
        );
      },
    );

    test('port refresh preserves visual baselines and defaults new plugin ports to minimum', () async {
      final nodeId = project.allocateId();
      final node = NodeModel(
        id: nodeId,
        controlInputPorts: AnthemObservableList.of([
          NodePortModel(
            presentation: ParameterPresentationModel(
              normalizedVisualBaseline: 0.25,
            ),
            nodeId: nodeId,
            id: 100,
            config: NodePortConfigModel(
              dataType: NodePortDataType.control,
              name: 'Previous name',
              parameterConfig: ParameterConfigModel(
                id: 100,
                factoryDefaultValue: 0.5,
                displayMode: ParameterDisplayMode.pluginText,
              ),
            ),
          ),
        ]),
      );
      project.processingGraph.addNode(node);
      final previousPort = node.controlInputPorts.single;
      final api = _RecordingProcessingGraphApi();
      api.results = [
        ProcessingGraphNodeInitializationResult(
          nodeId: nodeId,
          success: true,
          parameterValues: [],
          portConfiguration: ProcessingGraphNodePortConfiguration(
            audioInputPorts: [],
            audioOutputPorts: [],
            eventInputPorts: [],
            eventOutputPorts: [],
            controlOutputPorts: [],
            controlInputPorts: [
              ProcessingGraphPortConfiguration(
                id: 100,
                name: 'New name',
                parameterDefaultValue: 0.5,
                parameterDisplayMode: 'pluginText',
              ),
              ProcessingGraphPortConfiguration(
                id: 101,
                name: 'New parameter',
                parameterDefaultValue: 0.5,
                parameterDisplayMode: 'pluginText',
              ),
            ],
          ),
        ),
      ];
      project.engine.processingGraphApi = api;
      await controller.publishProcessingGraph();
      final refreshedPort = node.getPortById(100);
      expect(refreshedPort, same(previousPort));
      expect(refreshedPort.config.name, 'New name');
      expect(refreshedPort.presentation.normalizedVisualBaseline, 0.25);
      expect(node.getPortById(101).presentation.normalizedVisualBaseline, 0.0);
    });

    test('missing discovered ports keep routing, values and presentation and recover by ID', () async {
      final sourceId = project.allocateId();
      final destinationId = project.allocateId();
      final port = NodePortModel(
        id: 10,
        nodeId: destinationId,
        isAvailable: true,
        initialParameterValue: 0.7,
        parameterResetValue: 0.3,
        presentation: ParameterPresentationModel(
          normalizedVisualBaseline: 0.25,
        ),
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: 10,
            factoryDefaultValue: 0.5,
          ),
        ),
      );
      final source = NodeModel(
        id: sourceId,
        processor: GainProcessorModel(nodeId: sourceId),
        controlOutputPorts: AnthemObservableList.of([
          NodePortModel(
            id: 20,
            nodeId: sourceId,
            isAvailable: true,
            config: NodePortConfigModel(dataType: NodePortDataType.control),
          ),
        ]),
      );
      final destination = NodeModel(
        id: destinationId,
        processor: GainProcessorModel(nodeId: destinationId),
        controlInputPorts: AnthemObservableList.of([port]),
      );
      project.processingGraph.addNode(source);
      project.processingGraph.addNode(destination);
      final connection = NodeConnectionModel(
        idAllocator: project.idAllocator,
        sourceNodeId: sourceId,
        sourcePortId: 20,
        destinationNodeId: destinationId,
        destinationPortId: 10,
        dataType: NodePortDataType.control,
      );
      project.processingGraph.addConnection(connection);
      expect(project.processingGraph.isConnectionResolved(connection), isTrue);
      final api = _RecordingProcessingGraphApi();
      project.engine.processingGraphApi = api;
      ProcessingGraphNodePortConfiguration ports(
        List<ProcessingGraphPortConfiguration> control,
      ) => ProcessingGraphNodePortConfiguration(
        audioInputPorts: [],
        audioOutputPorts: [],
        eventInputPorts: [],
        eventOutputPorts: [],
        controlInputPorts: control,
        controlOutputPorts: [],
      );
      api.results = [
        ProcessingGraphNodeInitializationResult(
          nodeId: destinationId,
          success: true,
          portConfiguration: ports([]),
        ),
      ];
      await controller.publishProcessingGraph();
      expect(port.isAvailable, isFalse);
      expect(destination.controlInputPorts.single, same(port));
      expect(
        project.processingGraph.connections[connection.id],
        same(connection),
      );
      expect(port.connections, [connection.id]);
      expect(project.processingGraph.isConnectionResolved(connection), isFalse);
      expect(port.parameterValue, 0.7);
      expect(port.parameterResetTarget, 0.3);
      expect(port.presentation.normalizedVisualBaseline, 0.25);
      final saved = project.processingGraph.toJson();
      final reopened = ProcessingGraphModel.fromJson(saved);
      expect(reopened.toJson(), saved);
      expect(reopened.connections, contains(connection.id));
      final reopenedSource =
          reopened.nodes[sourceId]!.controlOutputPorts.single;
      final reopenedDestination =
          reopened.nodes[destinationId]!.controlInputPorts.single;
      for (final reopenedPort in [reopenedSource, reopenedDestination]) {
        expect(reopenedPort.connections, [connection.id]);
        expect(reopenedPort.isAvailable, isFalse);
      }
      final reopenedConnection = reopened.connections[connection.id]!;
      expect(reopened.isConnectionResolved(reopenedConnection), isFalse);
      reopenedSource.isAvailable = true;
      reopenedDestination.isAvailable = true;
      expect(reopened.isConnectionResolved(reopenedConnection), isTrue);
      api.results = [
        ProcessingGraphNodeInitializationResult(
          nodeId: destinationId,
          success: true,
          portConfiguration: ports([
            ProcessingGraphPortConfiguration(
              id: 10,
              name: 'Recovered',
              parameterDefaultValue: 0.9,
            ),
          ]),
          parameterValues: [
            ProcessingGraphParameterValue(controlPortId: 10, value: 0.6),
          ],
        ),
      ];
      await controller.publishProcessingGraph();
      expect(destination.controlInputPorts.single, same(port));
      expect(port.isAvailable, isTrue);
      expect(project.processingGraph.isConnectionResolved(connection), isTrue);
      expect(port.parameterValue, 0.6);
      expect(port.parameterResetTarget, 0.3);
      expect(port.config.parameterConfig!.factoryDefaultValue, 0.9);
      expect(port.presentation.normalizedVisualBaseline, 0.25);
      expect(
        project.processingGraph.connections[connection.id],
        same(connection),
      );
    });

    test('rack rebuild preserves routing when a plugin port disappears and returns', () async {
      final graph = project.processingGraph;
      final track = project.tracks[project.trackOrder.first]!;
      final processing = track.requireProcessing;
      final instrument = DeviceFactories.toneGenerator(
        idAllocator: project.idAllocator,
      );
      final effect = DeviceFactories.vst3Plugin(
        idAllocator: project.idAllocator,
        vst3Path: '/test/effect.vst3',
      );
      graph.restoreGraphFragment(instrument.graphFragment);
      graph.restoreGraphFragment(effect.graphFragment);
      processing.devices.addAll([instrument.device, effect.device]);
      for (final node in graph.nodes.values) {
        for (final port in node.getAllPorts()) {
          port.isAvailable = true;
        }
      }

      final instrumentNode = instrument.graphFragment.nodes.single;
      final effectNode = effect.graphFragment.nodes.single;
      final inputId = VST3ProcessorModel.audioInputPortId;
      final outputId = VST3ProcessorModel.audioOutputPortId;
      final api = _RecordingProcessingGraphApi();
      project.engine.processingGraphApi = api;

      Future<void> discoverEffectPorts({required bool hasAudioInput}) async {
        api.results = [
          ProcessingGraphNodeInitializationResult(
            nodeId: effectNode.id,
            success: true,
            portConfiguration: ProcessingGraphNodePortConfiguration(
              audioInputPorts: [
                if (hasAudioInput)
                  ProcessingGraphPortConfiguration(
                    id: inputId,
                    channelCount: 2,
                  ),
              ],
              audioOutputPorts: [
                ProcessingGraphPortConfiguration(id: outputId, channelCount: 2),
              ],
              eventInputPorts: [],
              eventOutputPorts: [],
              controlInputPorts: [],
              controlOutputPorts: [],
            ),
          ),
        ];
        await controller.publishProcessingGraph();
      }

      Iterable<NodeConnectionModel> rackConnections() => processing
          .deviceRoutingConnectionIds
          .map((id) => graph.connections[id]!);

      final expectedEndpoints = {
        (
          processing.sequenceNoteProviderNodeId!,
          SequenceNoteProviderProcessorModel.eventOutputPortId,
          instrumentNode.id,
          ToneGeneratorProcessorModel.eventInputPortId,
          NodePortDataType.event,
        ),
        (
          processing.liveEventProviderNodeId!,
          LiveEventProviderProcessorModel.eventOutputPortId,
          instrumentNode.id,
          ToneGeneratorProcessorModel.eventInputPortId,
          NodePortDataType.event,
        ),
        (
          instrumentNode.id,
          ToneGeneratorProcessorModel.audioOutputPortId,
          effectNode.id,
          inputId,
          NodePortDataType.audio,
        ),
        (
          effectNode.id,
          outputId,
          processing.utilityNodeId!,
          UtilityProcessorModel.audioInputPortId,
          NodePortDataType.audio,
        ),
      };

      void expectRackRouting() {
        final connections = rackConnections().toList();
        expect(connections, hasLength(expectedEndpoints.length));
        expect(
          connections
              .map(
                (connection) => (
                  connection.sourceNodeId,
                  connection.sourcePortId,
                  connection.destinationNodeId,
                  connection.destinationPortId,
                  connection.dataType,
                ),
              )
              .toSet(),
          expectedEndpoints,
        );
      }

      await discoverEffectPorts(hasAudioInput: true);
      final input = effectNode.audioInputPorts.single;
      expectRackRouting();
      expect(rackConnections().every(graph.isConnectionResolved), isTrue);

      await discoverEffectPorts(hasAudioInput: false);
      expect(effectNode.audioInputPorts.single, same(input));
      expect(input.isAvailable, isFalse);
      expect(effect.device.defaultAudioInputPort!.portId, inputId);
      expectRackRouting();
      expect(
        rackConnections()
            .where((connection) => !graph.isConnectionResolved(connection))
            .single
            .destinationNodeId,
        effectNode.id,
      );

      await discoverEffectPorts(hasAudioInput: true);
      expect(effectNode.audioInputPorts.single, same(input));
      expect(input.isAvailable, isTrue);
      expectRackRouting();
      expect(rackConnections().every(graph.isConnectionResolved), isTrue);
    });

    test(
      'failed initialization suspends routing without deleting it',
      () async {
        final node = project.processingGraph.getMasterOutputNode();
        final ports = node.getAllPorts().toList();
        final connectionIds = project.processingGraph.connections.keys.toList();
        final api = _RecordingProcessingGraphApi()
          ..results = [
            ProcessingGraphNodeInitializationResult(
              nodeId: node.id,
              success: false,
              error: 'Unavailable',
            ),
          ];
        project.engine.processingGraphApi = api;
        await controller.publishProcessingGraph();
        expect(ports.every((port) => !port.isAvailable), isTrue);
        expect(
          project.processingGraph.connections.keys,
          containsAll(connectionIds),
        );
        for (final id in connectionIds) {
          final connection = project.processingGraph.connections[id]!;
          if (connection.sourceNodeId == node.id ||
              connection.destinationNodeId == node.id) {
            expect(
              project.processingGraph.isConnectionResolved(connection),
              isFalse,
            );
          }
        }
      },
    );

    test(
      'publishProcessingGraph does not mark initialized parameters as touched',
      () async {
        final processingGraphApi = _RecordingProcessingGraphApi();
        final nodeId = project.allocateId();
        final node = NodeModel(
          id: nodeId,
          controlInputPorts: AnthemObservableList.of([
            NodePortModel(
              nodeId: nodeId,
              id: 100,
              config: NodePortConfigModel(
                dataType: NodePortDataType.control,
                parameterConfig: ParameterConfigModel(
                  id: 100,
                  factoryDefaultValue: 0.5,
                ),
              ),
            ),
          ]),
        );
        final port = node.controlInputPorts.single;
        project.processingGraph.addNode(node);

        processingGraphApi.results = [
          ProcessingGraphNodeInitializationResult(
            nodeId: node.id,
            success: true,
            parameterValues: [
              ProcessingGraphParameterValue(
                controlPortId: port.id,
                value: 0.25,
                displayText: '25%',
              ),
            ],
          ),
        ];
        project.engine.processingGraphApi = processingGraphApi;

        await controller.publishProcessingGraph();

        expect(port.parameterValue, equals(0.25));
        expect(port.parameterDisplayText, equals('25%'));
        expect(node.lastChangedControlPortId, isNull);
      },
    );
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
