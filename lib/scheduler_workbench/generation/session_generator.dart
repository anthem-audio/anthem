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

import 'dart:math';

import 'package:mobx/mobx.dart';

import '../models/node.dart';
import '../models/node_connection.dart';
import '../models/node_port.dart';
import '../models/processing_graph.dart';
import '../models/session.dart';
import '../models/track.dart';
import 'generation_settings.dart';

class SessionGenerator {
  static const double _trackSpacing = 420;
  static const double _stepSpacing = 170;
  static const double _splitSpacing = 170;
  static const double _baselineY = 0;
  static const double _sendRowY = 230;
  static const double _sendSpacing = 280;

  void generate({
    required ProcessingGraphModel graph,
    required SessionModel session,
    required GenerationSettings settings,
  }) {
    final random = Random(settings.seed);
    final tracks = <TrackModel>[];
    final sendNodeIds = <int>[];

    graph.clear();

    final sessionWidth = max(1, settings.trackCount - 1) * _trackSpacing;
    final routingNodeCount = settings.sendCount + 1;
    final routingRowStartX =
        sessionWidth / 2 - (routingNodeCount - 1) * _sendSpacing / 2;

    final masterNode = _createNode(
      graph: graph,
      name: 'Master',
      x: routingRowStartX + settings.sendCount * _sendSpacing,
      y: _sendRowY,
    );

    for (var i = 0; i < settings.sendCount; i++) {
      final sendNode = _createNode(
        graph: graph,
        name: 'Send ${i + 1}',
        x: routingRowStartX + i * _sendSpacing,
        y: _sendRowY,
      );

      sendNodeIds.add(sendNode.id);
      _connect(graph, sendNode, masterNode);
    }

    for (var i = 0; i < settings.trackCount; i++) {
      final track = _createTrack(
        graph: graph,
        random: random,
        settings: settings,
        trackIndex: i,
      );

      tracks.add(track);

      final trackOutputNode = graph.nodes[track.outputNodeId]!;
      final targetNodeId = sendNodeIds.isNotEmpty && random.nextBool()
          ? sendNodeIds[random.nextInt(sendNodeIds.length)]
          : masterNode.id;
      final targetNode = graph.nodes[targetNodeId]!;

      _connect(graph, trackOutputNode, targetNode);
    }

    _addBusTrackConnections(
      graph: graph,
      tracks: tracks,
      random: random,
      busTrackCount: settings.busTrackCount,
      tracksPerBus: settings.busTrackInputCount,
    );
    _removeCycles(graph);

    _addCrossTrackConnections(
      graph: graph,
      tracks: tracks,
      random: random,
      connectionCount: settings.crossTrackConnectionCount,
    );
    _removeCycles(graph);

    session.replace(
      tracks: tracks,
      sendNodeIds: sendNodeIds,
      masterNodeId: masterNode.id,
    );
  }

  TrackModel _createTrack({
    required ProcessingGraphModel graph,
    required Random random,
    required GenerationSettings settings,
    required int trackIndex,
  }) {
    final trackId = graph.allocateId();
    final trackName = 'Track ${trackIndex + 1}';
    final stepCount =
        settings.minNodeSteps +
        random.nextInt(settings.maxNodeSteps - settings.minNodeSteps + 1);
    final trackNodes = <NodeModel>[];
    var activeNodes = <NodeModel>[];
    final trackX = trackIndex * _trackSpacing;

    for (var step = 0; step < stepCount - 1; step++) {
      final y = _baselineY - (stepCount - 1 - step) * _stepSpacing;
      final layer = _createLayer(
        graph: graph,
        random: random,
        settings: settings,
        trackName: trackName,
        trackX: trackX,
        step: step,
        y: y,
        previousNodes: activeNodes,
      );

      activeNodes = layer;
      trackNodes.addAll(layer);
    }

    final outputNode = _createNode(
      graph: graph,
      name: '$trackName Output',
      x: trackX,
      y: _baselineY,
    );
    trackNodes.add(outputNode);

    for (final activeNode in activeNodes) {
      _connect(graph, activeNode, outputNode);
    }

    if (activeNodes.isEmpty) {
      // A one-step track consists of only the output node.
      activeNodes = [outputNode];
    }

    return TrackModel(
      id: trackId,
      name: trackName,
      outputNodeId: outputNode.id,
      nodeIds: ObservableList.of([for (final node in trackNodes) node.id]),
    );
  }

  List<NodeModel> _createLayer({
    required ProcessingGraphModel graph,
    required Random random,
    required GenerationSettings settings,
    required String trackName,
    required double trackX,
    required int step,
    required double y,
    required List<NodeModel> previousNodes,
  }) {
    final channelCount = _nextChannelCount(
      previousChannelCount: previousNodes.length,
      random: random,
      settings: settings,
    );
    final layer = <NodeModel>[];

    for (var channel = 0; channel < channelCount; channel++) {
      final node = _createNode(
        graph: graph,
        name:
            '$trackName Node ${step + 1}${_channelLabel(channelCount, channel)}',
        x: _channelX(trackX, channelCount, channel),
        y: y,
      );

      layer.add(node);
    }

    _connectLayers(
      graph: graph,
      previousNodes: previousNodes,
      currentNodes: layer,
      random: random,
    );

    return layer;
  }

  int _nextChannelCount({
    required int previousChannelCount,
    required Random random,
    required GenerationSettings settings,
  }) {
    if (previousChannelCount == 0) {
      return 1;
    }

    if (previousChannelCount > 1 &&
        random.nextDouble() < settings.recombineChance) {
      return previousChannelCount - 1;
    }

    if (random.nextDouble() < settings.splitChance) {
      return previousChannelCount + 1;
    }

    return previousChannelCount;
  }

  double _channelX(double trackX, int channelCount, int channel) {
    return trackX + (channel - (channelCount - 1) / 2) * _splitSpacing;
  }

  String _channelLabel(int channelCount, int channel) {
    if (channelCount == 1) {
      return '';
    }

    return ' ${String.fromCharCode(65 + channel)}';
  }

  void _connectLayers({
    required ProcessingGraphModel graph,
    required List<NodeModel> previousNodes,
    required List<NodeModel> currentNodes,
    required Random random,
  }) {
    if (previousNodes.isEmpty) {
      return;
    }

    if (currentNodes.length == previousNodes.length + 1) {
      final splitIndex = random.nextInt(previousNodes.length);

      for (var i = 0; i < currentNodes.length; i++) {
        if (i < splitIndex) {
          _connect(graph, previousNodes[i], currentNodes[i]);
        } else if (i <= splitIndex + 1) {
          _connect(graph, previousNodes[splitIndex], currentNodes[i]);
        } else {
          _connect(graph, previousNodes[i - 1], currentNodes[i]);
        }
      }

      return;
    }

    if (currentNodes.length == previousNodes.length - 1) {
      final recombineIndex = random.nextInt(previousNodes.length - 1);

      for (var i = 0; i < currentNodes.length; i++) {
        if (i < recombineIndex) {
          _connect(graph, previousNodes[i], currentNodes[i]);
        } else if (i == recombineIndex) {
          _connect(graph, previousNodes[i], currentNodes[i]);
          _connect(graph, previousNodes[i + 1], currentNodes[i]);
        } else {
          _connect(graph, previousNodes[i + 1], currentNodes[i]);
        }
      }

      return;
    }

    for (var i = 0; i < currentNodes.length; i++) {
      _connect(graph, previousNodes[i], currentNodes[i]);
    }
  }

  NodeModel _createNode({
    required ProcessingGraphModel graph,
    required String name,
    required double x,
    required double y,
  }) {
    final nodeId = graph.allocateId();
    final inputPortId = graph.allocateId();
    final outputPortId = graph.allocateId();
    final node = NodeModel(
      id: nodeId,
      name: name,
      x: x,
      y: y,
      audioInputPorts: ObservableList.of([
        NodePortModel(
          id: inputPortId,
          nodeId: nodeId,
          name: 'Audio In',
          dataType: PortDataType.audio,
          direction: PortDirection.input,
        ),
      ]),
      audioOutputPorts: ObservableList.of([
        NodePortModel(
          id: outputPortId,
          nodeId: nodeId,
          name: 'Audio Out',
          dataType: PortDataType.audio,
          direction: PortDirection.output,
        ),
      ]),
    );

    graph.addNode(node);
    return node;
  }

  void _connect(
    ProcessingGraphModel graph,
    NodeModel source,
    NodeModel target,
  ) {
    graph.addConnection(
      NodeConnectionModel(
        id: graph.allocateId(),
        sourceNodeId: source.id,
        sourcePortId: source.audioOutputPorts.first.id,
        destinationNodeId: target.id,
        destinationPortId: target.audioInputPorts.first.id,
      ),
    );
  }

  void _addCrossTrackConnections({
    required ProcessingGraphModel graph,
    required List<TrackModel> tracks,
    required Random random,
    required int connectionCount,
  }) {
    if (connectionCount <= 0) {
      return;
    }

    final eligibleTracks = tracks
        .where((track) => track.nodeIds.isNotEmpty)
        .toList(growable: false);

    if (eligibleTracks.length < 2) {
      return;
    }

    final existingConnectionKeys = <String>{
      for (final connection in graph.connections.values)
        _connectionKey(connection.sourceNodeId, connection.destinationNodeId),
    };
    final maxAttempts = max(1, connectionCount * 12);
    var addedConnectionCount = 0;
    var attemptCount = 0;

    while (addedConnectionCount < connectionCount &&
        attemptCount < maxAttempts) {
      attemptCount++;

      final sourceTrackIndex = random.nextInt(eligibleTracks.length);
      var targetTrackIndex = random.nextInt(eligibleTracks.length - 1);

      if (targetTrackIndex >= sourceTrackIndex) {
        targetTrackIndex++;
      }

      final sourceTrack = eligibleTracks[sourceTrackIndex];
      final targetTrack = eligibleTracks[targetTrackIndex];
      final sourceNodeId =
          sourceTrack.nodeIds[random.nextInt(sourceTrack.nodeIds.length)];
      final targetNodeId =
          targetTrack.nodeIds[random.nextInt(targetTrack.nodeIds.length)];
      final connectionKey = _connectionKey(sourceNodeId, targetNodeId);

      if (!existingConnectionKeys.add(connectionKey)) {
        continue;
      }

      final sourceNode = graph.nodes[sourceNodeId];
      final targetNode = graph.nodes[targetNodeId];

      if (sourceNode == null || targetNode == null) {
        continue;
      }

      _connect(graph, sourceNode, targetNode);
      addedConnectionCount++;
    }
  }

  void _addBusTrackConnections({
    required ProcessingGraphModel graph,
    required List<TrackModel> tracks,
    required Random random,
    required int busTrackCount,
    required int tracksPerBus,
  }) {
    if (busTrackCount <= 0 || tracksPerBus <= 0 || tracks.length < 2) {
      return;
    }

    final destinationTracks = tracks.toList(growable: false)..shuffle(random);
    final existingConnectionKeys = <String>{
      for (final connection in graph.connections.values)
        _connectionKey(connection.sourceNodeId, connection.destinationNodeId),
    };

    for (final destinationTrack in destinationTracks.take(busTrackCount)) {
      final destinationNodeIds = _getTrackEntryNodeIds(
        graph: graph,
        track: destinationTrack,
      );

      if (destinationNodeIds.isEmpty) {
        continue;
      }

      final sourceTracks =
          tracks
              .where((track) => track.id != destinationTrack.id)
              .toList(growable: false)
            ..shuffle(random);

      for (final sourceTrack in sourceTracks.take(tracksPerBus)) {
        final sourceNode = graph.nodes[sourceTrack.outputNodeId];

        if (sourceNode == null) {
          continue;
        }

        for (final destinationNodeId in destinationNodeIds) {
          final destinationNode = graph.nodes[destinationNodeId];

          if (destinationNode == null) {
            continue;
          }

          final connectionKey = _connectionKey(
            sourceNode.id,
            destinationNodeId,
          );

          if (!existingConnectionKeys.add(connectionKey)) {
            continue;
          }

          _connect(graph, sourceNode, destinationNode);
        }
      }
    }
  }

  List<int> _getTrackEntryNodeIds({
    required ProcessingGraphModel graph,
    required TrackModel track,
  }) {
    final trackNodeIds = track.nodeIds.toSet();
    final internallyDrivenNodeIds = <int>{};

    for (final connection in graph.connections.values) {
      if (trackNodeIds.contains(connection.sourceNodeId) &&
          trackNodeIds.contains(connection.destinationNodeId)) {
        internallyDrivenNodeIds.add(connection.destinationNodeId);
      }
    }

    return track.nodeIds
        .where((nodeId) => !internallyDrivenNodeIds.contains(nodeId))
        .toList(growable: false);
  }

  void _removeCycles(ProcessingGraphModel graph) {
    final adjacency = <int, List<NodeConnectionModel>>{};

    for (final connection in graph.connections.values) {
      adjacency
          .putIfAbsent(connection.sourceNodeId, () => <NodeConnectionModel>[])
          .add(connection);
    }

    final visitStates = <int, _CycleVisitState>{};
    final connectionIdsToRemove = <int>{};

    void visit(int nodeId) {
      visitStates[nodeId] = _CycleVisitState.visiting;

      for (final connection
          in adjacency[nodeId] ?? const <NodeConnectionModel>[]) {
        if (connectionIdsToRemove.contains(connection.id)) {
          continue;
        }

        final targetState = visitStates[connection.destinationNodeId];

        if (targetState == _CycleVisitState.visiting) {
          connectionIdsToRemove.add(connection.id);
          continue;
        }

        if (targetState == null) {
          visit(connection.destinationNodeId);
        }
      }

      visitStates[nodeId] = _CycleVisitState.visited;
    }

    for (final nodeId in graph.nodes.keys.toList(growable: false)) {
      if (visitStates[nodeId] == null) {
        visit(nodeId);
      }
    }

    for (final connectionId in connectionIdsToRemove) {
      graph.removeConnection(connectionId);
    }
  }

  String _connectionKey(int sourceNodeId, int targetNodeId) {
    return '$sourceNodeId:$targetNodeId';
  }
}

enum _CycleVisitState { visiting, visited }
