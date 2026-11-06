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

import 'dart:async';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/processing_graph_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/parameter_engine.dart';

class _GraphApi extends Fake implements ProcessingGraphApi {
  final calls = <String>[];
  Future<ProcessingGraphNodeInitialization> Function()? onInitialize;
  Future<String?> Function(int)? onCapture;
  Future<String> Function(int)? onSave;

  @override
  Future<void> waitForPendingParameterEdits(int nodeId) async {}

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async {
    calls.add('initialize');
    return onInitialize?.call() ??
        ProcessingGraphNodeInitialization(didInitialize: true, results: []);
  }

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodesForRender() async {
    calls.add('initialize-render');
    return ProcessingGraphNodeInitialization(didInitialize: true, results: []);
  }

  @override
  Future<void> publish() async {
    calls.add('publish');
  }

  @override
  Future<void> publishForRender() async {
    calls.add('publish-render');
  }

  @override
  Future<String?> captureProcessorState(int nodeId) async {
    calls.add('capture:$nodeId');
    return onCapture?.call(nodeId);
  }

  @override
  Future<String> saveSnapshot(int nodeId) async {
    calls.add('save:$nodeId');
    return onSave!(nodeId);
  }
}

class _GraphEngine extends Fake implements Engine {
  @override
  final ProjectModel project;
  @override
  final _GraphApi processingGraphApi = _GraphApi();
  Completer<void> session = Completer<void>();
  @override
  Future<void> get sessionEnded => session.future;
  bool running = true;
  @override
  bool get isRunning => running;
  @override
  bool get areRequestsHeldForRender => false;
  @override
  Stream<EngineState> get engineStateStream => const Stream.empty();

  _GraphEngine(this.project);

  void restart() {
    session.complete();
    session = Completer<void>();
  }

  @override
  Future<void> dispose() async {
    if (!session.isCompleted) session.complete();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

class _RecordingProcessingGraphApi extends ParameterTestApi {
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
  group('operation queue', () {
    late ProjectModel project;
    late _GraphEngine engine;
    late _GraphApi api;
    late ProcessingGraphController controller;
    late NodeModel node;

    setUp(() async {
      project = ProjectModel.create();
      await project.engine.dispose();
      engine = _GraphEngine(project);
      project.engine = engine;
      api = engine.processingGraphApi;
      controller = ServiceRegistry.initializeProject(project)
          .processingGraphController;
      node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      node.markInitialized();
    });

    tearDown(() async {
      await project.dispose();
      ServiceRegistry.removeProject(project.id);
    });

    test(
      'offline graph edits need no publication until the engine starts',
      () async {
        engine.running = false;
        await controller.publish();
        expect(api.calls, isEmpty);
        engine.running = true;
        await controller.publish();
        expect(api.calls, ['initialize', 'publish']);
      },
    );

    test(
      'a capture waits for initialization and publication to finish together',
      () async {
        final initialization = Completer<ProcessingGraphNodeInitialization>();
        api.onInitialize = () => initialization.future;
        final publishing = controller.publish();
        await flush();
        final capture = controller.captureProcessorState(node.id);
        await flush();
        expect(api.calls, ['initialize']);
        initialization.complete(
          ProcessingGraphNodeInitialization(didInitialize: true, results: []),
        );
        await publishing;
        await capture;
        expect(api.calls, ['initialize', 'publish', 'capture:${node.id}']);
      },
    );

    test('publication waits for an active capture', () async {
      final captured = Completer<String?>();
      api.onCapture = (_) => captured.future;
      final capture = controller.captureProcessorState(node.id);
      await flush();
      final publishing = controller.publish();
      await flush();
      expect(api.calls, ['capture:${node.id}']);
      captured.complete(null);
      await capture;
      await publishing;
      expect(api.calls, ['capture:${node.id}', 'initialize', 'publish']);
    });

    test(
      'coalescing never moves a publication across a state operation',
      () async {
        final captured = Completer<String?>();
        api.onCapture = (_) => captured.future;
        final firstCapture = controller.captureProcessorState(node.id);
        await flush();
        final firstPublish = controller.publish();
        final adjacentPublish = controller.publish();
        expect(adjacentPublish, same(firstPublish));
        final secondCapture = controller.captureProcessorState(node.id);
        final lastPublish = controller.publish();
        expect(lastPublish, isNot(same(firstPublish)));
        captured.complete(null);
        await Future.wait([
          firstCapture,
          firstPublish,
          adjacentPublish,
          secondCapture,
          lastPublish,
        ]);
        expect(api.calls, [
          'capture:${node.id}',
          'initialize',
          'publish',
          'capture:${node.id}',
          'initialize',
          'publish',
        ]);
      },
    );

    test(
      'failed snapshot work clears node policy before the next operation',
      () async {
        final saved = Completer<String>();
        api.onSave = (_) => saved.future;
        final saving = controller.saveSnapshot(node.id);
        final failed = expectLater(saving, throwsStateError);
        await flush();
        expect(node.canEditParameters, isFalse);
        final publishing = controller.publish();
        await flush();
        expect(api.calls, ['save:${node.id}']);
        saved.completeError(StateError('Capture failed.'));
        await failed;
        await publishing;
        expect(node.canEditParameters, isTrue);
        expect(api.calls, ['save:${node.id}', 'initialize', 'publish']);
      },
    );

    test(
      'old-session work cannot apply descriptions or run after restart',
      () async {
        final initialization = Completer<ProcessingGraphNodeInitialization>();
        api.onInitialize = () => initialization.future;
        final publishing = controller.publish();
        final failedPublish = expectLater(publishing, throwsStateError);
        await flush();
        final capture = controller.captureProcessorState(node.id);
        final failedCapture = expectLater(capture, throwsStateError);
        engine.restart();
        initialization.complete(
          ProcessingGraphNodeInitialization(didInitialize: true, results: []),
        );
        await failedPublish;
        await failedCapture;
        expect(api.calls, ['initialize']);
        await controller.publish();
        expect(api.calls, ['initialize', 'initialize', 'publish']);
      },
    );

    test(
      'disposing the service prevents active reconciliation and queued work',
      () async {
        final initialization = Completer<ProcessingGraphNodeInitialization>();
        api.onInitialize = () => initialization.future;
        final publishing = controller.publish();
        final failedPublish = expectLater(publishing, throwsStateError);
        await flush();
        final capture = controller.captureProcessorState(node.id);
        final failedCapture = expectLater(capture, throwsStateError);
        controller.dispose();
        initialization.complete(
          ProcessingGraphNodeInitialization(didInitialize: true, results: []),
        );
        await failedPublish;
        await failedCapture;
        expect(api.calls, ['initialize']);
      },
    );

    test(
      'render setup and restoration hold one turn without nested queueing',
      () async {
        final captured = Completer<String?>();
        final rendered = Completer<void>();
        api.onCapture = (_) => captured.future;
        final capture = controller.captureProcessorState(node.id);
        await flush();
        final rendering = controller.runRender((publishGraph) async {
          api.calls.add('render-setup');
          await publishGraph();
          await rendered.future;
          api.calls.add('render-restore');
          await publishGraph();
        });
        final publishing = controller.publish();
        await flush();
        expect(api.calls, ['capture:${node.id}']);
        captured.complete(null);
        await capture;
        await flush();
        expect(api.calls, [
          'capture:${node.id}',
          'render-setup',
          'initialize-render',
          'publish-render',
        ]);
        rendered.complete();
        await rendering;
        await publishing;
        expect(api.calls, [
          'capture:${node.id}',
          'render-setup',
          'initialize-render',
          'publish-render',
          'render-restore',
          'initialize-render',
          'publish-render',
          'initialize',
          'publish',
        ]);
      },
    );
  });

  group('initialization and routing', () {
    late ProjectModel project;
    late ProcessingGraphController controller;

    setUp(() {
      project = ProjectModel.create();
      addTearDown(project.engine.dispose);
      controller = ServiceRegistry.initializeProject(project)
          .processingGraphController;
    });

    tearDown(() async {
      await project.dispose();
      ServiceRegistry.removeProject(project.id);
    });

    test('publish initializes nodes before publishing', () async {
      final processingGraphApi = _RecordingProcessingGraphApi();
      project.engine = ParameterTestEngine(
        project,
        processingGraphApi: processingGraphApi,
      );

      await controller.publish();

      expect(processingGraphApi.initializeNodesCallCount, equals(1));
      expect(processingGraphApi.publishCallCount, equals(1));
      expect(
        processingGraphApi.calls,
        orderedEquals(['initialize', 'publish']),
      );
    });

    test('publish skips publish when initialization did not run', () async {
      final processingGraphApi = _RecordingProcessingGraphApi()
        ..didInitialize = false;
      project.engine = ParameterTestEngine(
        project,
        processingGraphApi: processingGraphApi,
      );

      await controller.publish();

      expect(processingGraphApi.initializeNodesCallCount, equals(1));
      expect(processingGraphApi.publishCallCount, equals(0));
      expect(processingGraphApi.calls, orderedEquals(['initialize']));
    });

    test('publish coalesces queued publishes while in progress', () async {
      final processingGraphApi = _RecordingProcessingGraphApi();
      final publishCompleter = Completer<void>();
      processingGraphApi.publishCompleter = publishCompleter;
      project.engine = ParameterTestEngine(
        project,
        processingGraphApi: processingGraphApi,
      );

      final firstPublish = controller.publish();
      await _flushMicrotasks();

      final secondPublish = controller.publish();
      await _flushMicrotasks();

      final thirdPublish = controller.publish();
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
    });

    test('port refresh updates processor baselines and defaults new plugin ports to minimum', () async {
      final nodeId = project.allocateId();
      final node = NodeModel(
        id: nodeId,
        processor: GainProcessorModel(nodeId: nodeId),
        controlInputPorts: AnthemObservableList.of([
          NodePortModel(
            nodeId: nodeId,
            id: 100,
            config: NodePortConfigModel(
              dataType: NodePortDataType.control,
              name: 'Previous name',
              parameterConfig: ParameterConfigModel(
                id: 100,
                normalizedVisualBaseline: 0.25,
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
                parameterNormalizedVisualBaseline: 0.5,
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
      project.engine = ParameterTestEngine(project, processingGraphApi: api);
      String? nameWhenReady;
      int? portCountWhenReady;
      final disposeReaction = reaction((_) => node.initializationState, (
        state,
      ) {
        if (state == NodeInitializationState.ready) {
          nameWhenReady = previousPort.config.name;
          portCountWhenReady = node.controlInputPorts.length;
        }
      });
      addTearDown(disposeReaction.call);
      await controller.publish();
      expect(nameWhenReady, 'New name');
      expect(portCountWhenReady, 2);
      final refreshedPort = node.getPortById(100);
      expect(refreshedPort, same(previousPort));
      expect(refreshedPort.config.name, 'New name');
      expect(
        refreshedPort.config.parameterConfig!.normalizedVisualBaseline,
        0.5,
      );
      expect(
        node.getPortById(101).config.parameterConfig!.normalizedVisualBaseline,
        0.0,
      );
    });

    test(
      'metadata-only reports and repeated reports preserve rack connections',
      () async {
        final graph = project.processingGraph;
        final track = project.tracks[project.trackOrder.first]!;
        final processing = track.requireProcessing;
        final created = DeviceFactories.utility(
          idAllocator: project.idAllocator,
        );
        graph.restoreGraphFragment(created.graphFragment);
        processing.devices.add(created.device);
        final node = graph.nodes[created.device.nodeIds.single]!;
        final api = _RecordingProcessingGraphApi();
        final report = testUtilityInitialization(node);
        api.results = [report];
        project.engine = ParameterTestEngine(project, processingGraphApi: api);
        await controller.publish();
        final connectionIds = processing.deviceRoutingConnectionIds.toList();
        expect(connectionIds, isNotEmpty);
        final descriptor = report.portConfiguration!.controlInputPorts.first;
        final port = node.getPortById(descriptor.id);
        final parameter = port.config.parameterConfig!;
        final value = port.parameterValue;
        descriptor.name = 'Updated gain';
        descriptor.parameterNormalizedVisualBaseline = 0.25;
        descriptor.parameterDefaultValue = 0.6;
        await controller.publish();
        expect(port.config.name, 'Updated gain');
        expect(port.config.parameterConfig, same(parameter));
        expect(parameter.normalizedVisualBaseline, 0.25);
        expect(parameter.factoryDefaultValue, 0.6);
        expect(port.parameterValue, value);
        expect(processing.deviceRoutingConnectionIds, connectionIds);

        await controller.publish();
        expect(processing.deviceRoutingConnectionIds, connectionIds);
      },
    );

    test('missing discovered ports keep routing, values and presentation and recover by ID', () async {
      final sourceId = project.allocateId();
      final destinationId = project.allocateId();
      final port = NodePortModel(
        id: 10,
        nodeId: destinationId,
        isAvailable: true,
        initialParameterValue: 0.7,
        parameterResetValue: 0.3,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: 10,
            normalizedVisualBaseline: 0.25,
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
      project.engine = ParameterTestEngine(project, processingGraphApi: api);
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
      await controller.publish();
      expect(destination.initializationState, NodeInitializationState.ready);
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
      expect(port.config.parameterConfig!.normalizedVisualBaseline, 0.25);
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
      await controller.publish();
      expect(destination.controlInputPorts.single, same(port));
      expect(port.isAvailable, isTrue);
      expect(project.processingGraph.isConnectionResolved(connection), isTrue);
      expect(port.parameterValue, 0.6);
      expect(port.parameterResetTarget, 0.3);
      expect(port.config.parameterConfig!.factoryDefaultValue, 0.9);
      expect(port.config.parameterConfig!.normalizedVisualBaseline, 0.0);
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
      project.engine = ParameterTestEngine(project, processingGraphApi: api);

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
        await controller.publish();
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
        project.engine = ParameterTestEngine(project, processingGraphApi: api);
        await controller.publish();
        expect(node.initializationState, NodeInitializationState.failed);
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

    test('publish does not mark initialized parameters as touched', () async {
      final processingGraphApi = _RecordingProcessingGraphApi();
      final nodeId = project.allocateId();
      final node = NodeModel(
        id: nodeId,
        processor: GainProcessorModel(nodeId: nodeId),
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
      project.engine = ParameterTestEngine(
        project,
        processingGraphApi: processingGraphApi,
      );

      await controller.publish();

      expect(port.parameterValue, equals(0.25));
      expect(port.parameterDisplayText, equals('25%'));
      expect(node.lastChangedControlPortId, isNull);
    });
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
