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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/track_controller.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<ProjectModel>(), MockSpec<TrackModel>()])
import 'track_controller_test.mocks.dart';

class _FakeProcessingGraphApi extends Fake implements ProcessingGraphApi {
  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: true, results: []);

  @override
  Future<void> publish() async {}
}

class _MockEngine extends Mock implements Engine {
  final ProcessingGraphApi _processingGraphApi;

  _MockEngine(this._processingGraphApi);

  @override
  bool get isRunning => false;

  @override
  ProcessingGraphApi get processingGraphApi => _processingGraphApi;
}

void _createAndRegisterTrackNodes({
  required TrackModel track,
  required ProjectModel project,
  required ProjectEntityIdAllocator idAllocator,
}) {
  track.setParentPropertiesOnChildren();
  track.createAndRegisterNodes(project, idAllocator);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getTracksIterable()', () {
    test('can exclude or include descendants of collapsed groups', () {
      final project = ProjectModel.create();
      ServiceRegistry.initializeProject(project);
      addTearDown(() {
        ServiceRegistry.removeProject(project.id);
        project.dispose();
      });

      final childTrackId = project.trackOrder.first;
      final groupTrack = TrackModel(
        idAllocator: project.idAllocator,
        name: 'Group',
        color: AnthemColor.randomHue(),
        type: .group,
      )..childTracks.add(childTrackId);
      project.tracks[childTrackId]!.parentTrackId = groupTrack.id;
      project.tracks[groupTrack.id] = groupTrack;
      project.trackOrder[0] = groupTrack.id;

      final services = ServiceRegistry.forProject(project.id);
      services.arrangerViewModel.registerTrack(groupTrack.id);

      expect(
        services.trackController.getTracksIterable().map((entry) => entry.$1),
        contains(childTrackId),
      );

      services.arrangerViewModel.setGroupExpanded(groupTrack.id, false);

      expect(
        services.trackController.getTracksIterable().map((entry) => entry.$1),
        isNot(contains(childTrackId)),
      );
      expect(
        services.trackController
            .getTracksIterable(includeCollapsedTracks: true)
            .map((entry) => entry.$1),
        contains(childTrackId),
      );
    });
  });

  group('getTrackFxChainAudioInput()', () {
    final projectId = getProjectId();

    late MockProjectModel project;
    late TrackController trackController;
    late ProcessingGraphModel processingGraph;
    late _MockEngine mockEngine;
    late ProjectEntityIdAllocator idAllocator;
    late TrackModel track;

    setUp(() {
      project = MockProjectModel();
      when(project.id).thenReturn(projectId);
      when(project.allocateId()).thenAnswer((_) => getId());

      idAllocator = ProjectEntityIdAllocator(project);
      processingGraph = ProcessingGraphModel.create(
        masterOutputNodeId: getId(),
      );
      when(project.processingGraph).thenReturn(processingGraph);

      mockEngine = _MockEngine(_FakeProcessingGraphApi());
      when(project.engine).thenReturn(mockEngine);

      track = TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: 'Track',
        color: AnthemColor.randomHue(),
        type: .normal,
      );
      _createAndRegisterTrackNodes(
        track: track,
        project: project,
        idAllocator: idAllocator,
      );

      when(
        project.tracks,
      ).thenReturn(AnthemObservableMap.of({track.id: track}));

      trackController = TrackController(project);
    });

    test('returns the utility node audio input pair', () {
      final result = trackController.getTrackFxChainAudioInput(track.id);

      expect(result.nodeId, equals(track.requireProcessing.utilityNodeId));
      expect(result.portId, equals(UtilityProcessorModel.audioInputPortId));
    });
  });

  group('getTrackMainRoutingDestination()', () {
    final projectId = getProjectId();

    late MockProjectModel project;
    late TrackController trackController;
    late ProcessingGraphModel processingGraph;
    late _MockEngine mockEngine;
    late ProjectEntityIdAllocator idAllocator;
    late TrackModel groupTrack;
    late TrackModel childTrack;
    late TrackModel topLevelTrack;
    late TrackModel masterTrack;

    TrackModel createTrack(String name, TrackType type) {
      return TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: name,
        color: AnthemColor.randomHue(),
        type: type,
      );
    }

    setUp(() {
      project = MockProjectModel();
      when(project.id).thenReturn(projectId);
      when(project.allocateId()).thenAnswer((_) => getId());

      idAllocator = ProjectEntityIdAllocator(project);
      processingGraph = ProcessingGraphModel.create(
        masterOutputNodeId: getId(),
      );
      when(project.processingGraph).thenReturn(processingGraph);

      mockEngine = _MockEngine(_FakeProcessingGraphApi());
      when(project.engine).thenReturn(mockEngine);

      groupTrack = createTrack('Group', .group);
      childTrack = createTrack('Child', .normal);
      topLevelTrack = createTrack('Top Level', .normal);
      masterTrack = createTrack('Master', .normal)..isMasterTrack = true;

      _createAndRegisterTrackNodes(
        track: groupTrack,
        project: project,
        idAllocator: idAllocator,
      );
      _createAndRegisterTrackNodes(
        track: childTrack,
        project: project,
        idAllocator: idAllocator,
      );
      _createAndRegisterTrackNodes(
        track: topLevelTrack,
        project: project,
        idAllocator: idAllocator,
      );
      _createAndRegisterTrackNodes(
        track: masterTrack,
        project: project,
        idAllocator: idAllocator,
      );

      groupTrack.childTracks.add(childTrack.id);
      childTrack.parentTrackId = groupTrack.id;

      when(project.tracks).thenReturn(
        AnthemObservableMap.of({
          groupTrack.id: groupTrack,
          childTrack.id: childTrack,
          topLevelTrack.id: topLevelTrack,
          masterTrack.id: masterTrack,
        }),
      );

      trackController = TrackController(project);
    });

    test('child tracks route to their parent FX-chain input', () {
      final result = trackController.getTrackMainRoutingDestination(
        childTrack.id,
      );

      expect(result.nodeId, equals(groupTrack.requireProcessing.utilityNodeId));
      expect(result.portId, equals(UtilityProcessorModel.audioInputPortId));
    });

    test(
      'top-level non-master tracks route to the master track FX-chain input',
      () {
        final result = trackController.getTrackMainRoutingDestination(
          topLevelTrack.id,
        );

        expect(
          result.nodeId,
          equals(masterTrack.requireProcessing.utilityNodeId),
        );
        expect(result.portId, equals(UtilityProcessorModel.audioInputPortId));
      },
    );

    test('the master track routes to the hardware output node', () {
      final result = trackController.getTrackMainRoutingDestination(
        masterTrack.id,
      );

      expect(result.nodeId, equals(processingGraph.masterOutputNodeId));
      expect(
        result.portId,
        equals(processingGraph.getMasterOutputNode().audioInputPorts.first.id),
      );
    });
  });

  group('canGroupTracks()', () {
    final projectId = getProjectId();
    late MockProjectModel project;

    late AnthemObservableMap<Id, MockTrackModel> tracks;
    late AnthemObservableList<Id> trackOrder;
    late AnthemObservableList<Id> sendTrackOrder;

    late MockTrackModel trackA;
    late MockTrackModel trackB;
    late MockTrackModel trackC;
    late MockTrackModel trackL;
    late MockTrackModel trackM;
    late MockTrackModel masterTrack;

    setUp(() {
      project = MockProjectModel();

      when(project.id).thenReturn(projectId);

      tracks = AnthemObservableMap();
      trackOrder = AnthemObservableList();
      sendTrackOrder = AnthemObservableList();

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
      when(project.sendTrackOrder).thenReturn(sendTrackOrder);

      // normal tracks: A (group) -> B, C
      final trackAId = getId();
      final trackBId = getId();
      final trackCId = getId();

      trackA = MockTrackModel();
      trackB = MockTrackModel();
      trackC = MockTrackModel();

      when(trackA.id).thenReturn(trackAId);
      when(trackB.id).thenReturn(trackBId);
      when(trackC.id).thenReturn(trackCId);

      when(trackA.type).thenReturn(TrackType.group);
      when(trackB.type).thenReturn(TrackType.normal);
      when(trackC.type).thenReturn(TrackType.normal);

      when(
        trackA.childTracks,
      ).thenReturn(AnthemObservableList.of([trackBId, trackCId]));
      when(trackB.childTracks).thenReturn(AnthemObservableList());
      when(trackC.childTracks).thenReturn(AnthemObservableList());

      when(trackA.parentTrackId).thenReturn(null);
      when(trackB.parentTrackId).thenReturn(trackAId);
      when(trackC.parentTrackId).thenReturn(trackAId);
      when(trackA.isMasterTrack).thenReturn(false);
      when(trackB.isMasterTrack).thenReturn(false);
      when(trackC.isMasterTrack).thenReturn(false);

      tracks[trackAId] = trackA;
      tracks[trackBId] = trackB;
      tracks[trackCId] = trackC;
      trackOrder.addAll([trackAId]);

      // Send tracks: L (group) -> M, plus Master
      final trackLId = getId();
      final trackMId = getId();
      final masterTrackId = getId();

      trackL = MockTrackModel();
      trackM = MockTrackModel();
      masterTrack = MockTrackModel();

      when(trackL.id).thenReturn(trackLId);
      when(trackM.id).thenReturn(trackMId);
      when(masterTrack.id).thenReturn(masterTrackId);

      when(trackL.type).thenReturn(TrackType.group);
      when(trackM.type).thenReturn(TrackType.normal);
      when(masterTrack.type).thenReturn(TrackType.normal);

      when(trackL.childTracks).thenReturn(AnthemObservableList.of([trackMId]));
      when(trackM.childTracks).thenReturn(AnthemObservableList());
      when(masterTrack.childTracks).thenReturn(AnthemObservableList());

      when(trackL.parentTrackId).thenReturn(null);
      when(trackM.parentTrackId).thenReturn(trackLId);
      when(masterTrack.parentTrackId).thenReturn(null);
      when(trackL.isMasterTrack).thenReturn(false);
      when(trackM.isMasterTrack).thenReturn(false);
      when(masterTrack.isMasterTrack).thenReturn(true);

      tracks[trackLId] = trackL;
      tracks[trackMId] = trackM;
      tracks[masterTrackId] = masterTrack;
      sendTrackOrder.addAll([trackLId, masterTrackId]);
    });

    test('Main test', () {
      final trackController = TrackController(project);

      expect(trackController.canGroupTracks([]), isFalse);

      expect(trackController.canGroupTracks([trackA.id, trackB.id]), isTrue);
      expect(trackController.canGroupTracks([trackB.id, trackC.id]), isTrue);
      expect(
        trackController.canGroupTracks([trackA.id, trackB.id, trackC.id]),
        isTrue,
      );

      expect(trackController.canGroupTracks([trackA.id, trackL.id]), isFalse);
      expect(trackController.canGroupTracks([trackB.id, trackM.id]), isFalse);

      expect(trackController.canGroupTracks([trackL.id, trackM.id]), isTrue);
      expect(
        trackController.canGroupTracks([trackL.id, masterTrack.id]),
        isFalse,
      );
      expect(trackController.canGroupTracks([masterTrack.id]), isFalse);
    });
  });

  group('getTrackColorTargetIds()', () {
    late MockProjectModel project;
    late TrackController trackController;
    late AnthemObservableMap<Id, TrackModel> tracks;

    late TrackModel parentTrack;
    late TrackModel automationLaneA;
    late TrackModel automationLaneB;
    late TrackModel normalTrack;

    TrackModel createTrack(String name, TrackType type) {
      return TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: name,
        color: AnthemColor.randomHue(),
        type: type,
      );
    }

    setUp(() {
      project = MockProjectModel();
      tracks = AnthemObservableMap();
      when(project.tracks).thenReturn(tracks);

      parentTrack = createTrack('Parent', .normal);
      automationLaneA = createTrack('Automation A', .automationLane)
        ..automationLaneParentTrackId = parentTrack.id;
      automationLaneB = createTrack('Automation B', .automationLane)
        ..automationLaneParentTrackId = parentTrack.id;
      normalTrack = createTrack('Normal', .normal);

      parentTrack.automationLanes.addAll([
        automationLaneA.id,
        automationLaneB.id,
      ]);

      tracks.addAll({
        parentTrack.id: parentTrack,
        automationLaneA.id: automationLaneA,
        automationLaneB.id: automationLaneB,
        normalTrack.id: normalTrack,
      });

      trackController = TrackController(project);
    });

    test('expands a parent track to include its automation lanes', () {
      expect(trackController.getTrackColorTargetIds([parentTrack.id]), [
        parentTrack.id,
        automationLaneA.id,
        automationLaneB.id,
      ]);
    });

    test(
      'expands an automation lane to include its parent and sibling lanes',
      () {
        expect(trackController.getTrackColorTargetIds([automationLaneB.id]), [
          parentTrack.id,
          automationLaneA.id,
          automationLaneB.id,
        ]);
      },
    );

    test(
      'deduplicates tracks when parent and automation lanes are selected',
      () {
        expect(
          trackController.getTrackColorTargetIds([
            automationLaneA.id,
            parentTrack.id,
            automationLaneB.id,
          ]),
          [parentTrack.id, automationLaneA.id, automationLaneB.id],
        );
      },
    );

    test('keeps unrelated selected tracks in the color target list', () {
      expect(
        trackController.getTrackColorTargetIds([
          normalTrack.id,
          automationLaneA.id,
        ]),
        [
          normalTrack.id,
          parentTrack.id,
          automationLaneA.id,
          automationLaneB.id,
        ],
      );
    });
  });

  group('insertTrackAt()', () {
    final projectId = getProjectId();

    late MockProjectModel project;
    late TrackController trackController;
    late ProcessingGraphModel processingGraph;
    late _MockEngine mockEngine;
    late ProjectEntityIdAllocator idAllocator;

    late AnthemObservableMap<Id, TrackModel> tracks;
    late AnthemObservableList<Id> trackOrder;
    late AnthemObservableList<Id> sendTrackOrder;

    late TrackModel regularGroup;
    late TrackModel regularChildA;
    late TrackModel regularChildB;
    late TrackModel regularTopA;
    late TrackModel regularTopB;

    late TrackModel sendGroup;
    late TrackModel sendChild;
    late TrackModel sendTop;
    late TrackModel masterTrack;

    TrackModel createTrack(String name, TrackType type) {
      return TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: name,
        color: AnthemColor.randomHue(),
        type: type,
      );
    }

    setUp(() {
      project = MockProjectModel();
      when(project.id).thenReturn(projectId);

      tracks = AnthemObservableMap();
      trackOrder = AnthemObservableList();
      sendTrackOrder = AnthemObservableList();

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
      when(project.sendTrackOrder).thenReturn(sendTrackOrder);
      when(project.allocateId()).thenAnswer((_) => getId());
      idAllocator = ProjectEntityIdAllocator(project);
      processingGraph = ProcessingGraphModel.create(
        masterOutputNodeId: getId(),
      );
      when(project.processingGraph).thenReturn(processingGraph);
      mockEngine = _MockEngine(_FakeProcessingGraphApi());
      when(project.engine).thenReturn(mockEngine);

      regularGroup = createTrack('Regular Group', .group);
      regularChildA = createTrack('Regular Child A', .normal);
      regularChildB = createTrack('Regular Child B', .normal);
      regularTopA = createTrack('Regular Top A', .normal);
      regularTopB = createTrack('Regular Top B', .normal);

      sendGroup = createTrack('Send Group', .group);
      sendChild = createTrack('Send Child', .normal);
      sendTop = createTrack('Send Top', .normal);
      masterTrack = createTrack('Master', .normal)..isMasterTrack = true;

      tracks.addAll({
        regularGroup.id: regularGroup,
        regularChildA.id: regularChildA,
        regularChildB.id: regularChildB,
        regularTopA.id: regularTopA,
        regularTopB.id: regularTopB,
        sendGroup.id: sendGroup,
        sendChild.id: sendChild,
        sendTop.id: sendTop,
        masterTrack.id: masterTrack,
      });

      regularGroup.childTracks.addAll([regularChildA.id, regularChildB.id]);
      regularChildA.parentTrackId = regularGroup.id;
      regularChildB.parentTrackId = regularGroup.id;

      sendGroup.childTracks.add(sendChild.id);
      sendChild.parentTrackId = sendGroup.id;

      trackOrder.addAll([regularGroup.id, regularTopA.id, regularTopB.id]);
      sendTrackOrder.addAll([sendGroup.id, sendTop.id, masterTrack.id]);

      final arrangerViewModel = ArrangerViewModel(project: project)
        ..baseTrackHeight = 40
        ..timeRange = TimeRange(0, 4);
      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(idAllocatorService, (_, _) => idAllocator),
          overrideService(
            arrangerViewModelService,
            (_, _) => arrangerViewModel,
          ),
        ]),
      );

      trackController = ServiceRegistry.forProject(project.id).trackController;

      for (final track in tracks.values) {
        if (track.type == TrackType.group) {
          processingGraph.restoreGraphFragment(
            trackController.buildTrackMixFragment(track),
          );
        } else {
          track.createAndRegisterNodes(project, idAllocator);
        }
      }

      trackController.rerouteTracks(tracks.keys);

      when(project.execute(any)).thenAnswer((invocation) {
        final command = invocation.positionalArguments[0] as Command;
        command.execute(project);
      });
    });

    tearDown(() {
      ServiceRegistry.removeProject(projectId);
    });

    test('group anchor inserts at end of group', () {
      final oldChildren = List<Id>.from(regularGroup.childTracks);

      trackController.insertTrackAt(regularGroup.id);

      expect(regularGroup.childTracks.length, equals(oldChildren.length + 1));
      expect(regularGroup.childTracks.take(oldChildren.length), oldChildren);

      final newTrackId = regularGroup.childTracks.last;
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, equals(regularGroup.id));
      expect(newTrack.type, equals(TrackType.normal));
    });

    test('regular child anchor inserts below within parent group', () {
      final oldChildren = List<Id>.from(regularGroup.childTracks);
      final anchorIndex = oldChildren.indexOf(regularChildA.id);

      trackController.insertTrackAt(regularChildA.id);

      expect(regularGroup.childTracks.length, equals(oldChildren.length + 1));

      final newTrackId = regularGroup.childTracks[anchorIndex + 1];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, equals(regularGroup.id));

      expect(regularGroup.childTracks[anchorIndex], equals(regularChildA.id));
      expect(
        regularGroup.childTracks[anchorIndex + 2],
        equals(regularChildB.id),
      );
    });

    test('top-level regular anchor inserts below in trackOrder', () {
      final oldTrackOrder = List<Id>.from(trackOrder);
      final anchorIndex = oldTrackOrder.indexOf(regularTopA.id);

      trackController.insertTrackAt(regularTopA.id);

      expect(trackOrder.length, equals(oldTrackOrder.length + 1));

      final newTrackId = trackOrder[anchorIndex + 1];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, isNull);

      expect(trackOrder[anchorIndex], equals(regularTopA.id));
      expect(trackOrder[anchorIndex + 2], equals(regularTopB.id));
    });

    test('addSendTrack inserts new send tracks at the start', () {
      final oldSendTrackOrder = List<Id>.from(sendTrackOrder);

      trackController.addSendTrack();
      final firstNewTrackId = sendTrackOrder.first;

      trackController.addSendTrack();
      final secondNewTrackId = sendTrackOrder.first;

      trackController.addSendTrack();
      final thirdNewTrackId = sendTrackOrder.first;

      expect(sendTrackOrder.length, equals(oldSendTrackOrder.length + 3));
      expect(
        sendTrackOrder.take(3),
        equals([thirdNewTrackId, secondNewTrackId, firstNewTrackId]),
      );
      expect(sendTrackOrder.skip(3), equals(oldSendTrackOrder));
      expect(sendTrackOrder.last, equals(masterTrack.id));

      for (final trackId in [
        firstNewTrackId,
        secondNewTrackId,
        thirdNewTrackId,
      ]) {
        final track = tracks[trackId];
        expect(track, isNotNull);
        expect(track!.parentTrackId, isNull);
      }
    });

    test('top-level send anchor inserts above in sendTrackOrder', () {
      final oldSendTrackOrder = List<Id>.from(sendTrackOrder);
      final anchorIndex = oldSendTrackOrder.indexOf(sendTop.id);

      trackController.insertTrackAt(sendTop.id);

      expect(sendTrackOrder.length, equals(oldSendTrackOrder.length + 1));

      final newTrackId = sendTrackOrder[anchorIndex];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, isNull);

      expect(sendTrackOrder[anchorIndex + 1], equals(sendTop.id));
      expect(sendTrackOrder.last, equals(masterTrack.id));
    });

    test('master track anchor inserts above master in sendTrackOrder', () {
      final oldSendTrackOrder = List<Id>.from(sendTrackOrder);
      final masterIndex = oldSendTrackOrder.indexOf(masterTrack.id);

      trackController.insertTrackAt(masterTrack.id);

      expect(sendTrackOrder.length, equals(oldSendTrackOrder.length + 1));

      final newTrackId = sendTrackOrder[masterIndex];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, isNull);

      expect(sendTrackOrder[masterIndex + 1], equals(masterTrack.id));
    });

    test('send child anchor inserts above within parent group', () {
      final oldChildren = List<Id>.from(sendGroup.childTracks);
      final anchorIndex = oldChildren.indexOf(sendChild.id);

      trackController.insertTrackAt(sendChild.id);

      expect(sendGroup.childTracks.length, equals(oldChildren.length + 1));

      final newTrackId = sendGroup.childTracks[anchorIndex];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, equals(sendGroup.id));

      expect(sendGroup.childTracks[anchorIndex + 1], equals(sendChild.id));
    });
  });

  group('remove clip and track content', () {
    final projectId = getProjectId();

    late MockProjectModel project;
    late TrackController trackController;
    late SequencerModel sequence;
    late ProcessingGraphModel processingGraph;
    late _MockEngine mockEngine;
    late ProjectEntityIdAllocator idAllocator;

    late AnthemObservableMap<Id, TrackModel> tracks;
    late AnthemObservableList<Id> trackOrder;
    late AnthemObservableList<Id> sendTrackOrder;

    late TrackModel groupTrack;
    late TrackModel childTrack;
    late TrackModel otherTrack;
    late TrackModel automationLane;
    late TrackModel masterTrack;

    late ArrangementModel arrangementA;

    late PatternModel orphanPatternA;
    late PatternModel orphanPatternB;
    late PatternModel automationLanePattern;
    late PatternModel sharedPattern;

    late ClipModel clipOnGroupOrphan;
    late ClipModel clipOnGroupShared;
    late ClipModel clipOnOtherShared;
    late ClipModel clipOnChildOrphan;
    late ClipModel clipOnAutomationLane;

    TrackModel createTrack(String name, TrackType type) {
      return TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: name,
        color: AnthemColor.randomHue(),
        type: type,
      );
    }

    ClipModel createClip({
      required Id patternId,
      required Id trackId,
      required int offset,
    }) {
      return ClipModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        patternId: patternId,
        trackId: trackId,
        offset: offset,
      );
    }

    setUp(() {
      project = MockProjectModel();
      when(project.id).thenReturn(projectId);

      sequence = SequencerModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
      );
      when(project.sequence).thenReturn(sequence);

      tracks = AnthemObservableMap();
      trackOrder = AnthemObservableList();
      sendTrackOrder = AnthemObservableList();

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
      when(project.sendTrackOrder).thenReturn(sendTrackOrder);

      when(project.allocateId()).thenAnswer((_) => getId());
      idAllocator = ProjectEntityIdAllocator(project);
      processingGraph = ProcessingGraphModel.create(
        masterOutputNodeId: getId(),
      );
      when(project.processingGraph).thenReturn(processingGraph);

      mockEngine = _MockEngine(_FakeProcessingGraphApi());
      when(project.engine).thenReturn(mockEngine);

      groupTrack = createTrack('Group', .group);
      childTrack = createTrack('Child', .normal);
      otherTrack = createTrack('Other', .normal);
      masterTrack = createTrack('Master', .normal)..isMasterTrack = true;

      groupTrack.childTracks.add(childTrack.id);
      childTrack.parentTrackId = groupTrack.id;

      tracks.addAll({
        groupTrack.id: groupTrack,
        childTrack.id: childTrack,
        otherTrack.id: otherTrack,
        masterTrack.id: masterTrack,
      });

      trackOrder.addAll([groupTrack.id, otherTrack.id]);
      sendTrackOrder.add(masterTrack.id);

      arrangementA = sequence.arrangement;

      orphanPatternA = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: 'Orphan A',
      );
      orphanPatternB = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: 'Orphan B',
      );
      automationLanePattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: 'Automation Lane Orphan',
      );
      sharedPattern = PatternModel(
        idAllocator: ProjectEntityIdAllocator.test(getId),
        name: 'Shared',
      );

      sequence.patterns[orphanPatternA.id] = orphanPatternA;
      sequence.patterns[orphanPatternB.id] = orphanPatternB;
      sequence.patterns[automationLanePattern.id] = automationLanePattern;
      sequence.patterns[sharedPattern.id] = sharedPattern;

      clipOnGroupOrphan = createClip(
        patternId: orphanPatternA.id,
        trackId: groupTrack.id,
        offset: 0,
      );
      clipOnGroupShared = createClip(
        patternId: sharedPattern.id,
        trackId: groupTrack.id,
        offset: 16,
      );
      clipOnOtherShared = createClip(
        patternId: sharedPattern.id,
        trackId: otherTrack.id,
        offset: 32,
      );
      clipOnChildOrphan = createClip(
        patternId: orphanPatternB.id,
        trackId: childTrack.id,
        offset: 48,
      );

      arrangementA.clips[clipOnGroupOrphan.id] = clipOnGroupOrphan;
      arrangementA.clips[clipOnGroupShared.id] = clipOnGroupShared;
      arrangementA.clips[clipOnOtherShared.id] = clipOnOtherShared;
      arrangementA.clips[clipOnChildOrphan.id] = clipOnChildOrphan;

      when(project.execute(any)).thenAnswer((invocation) {
        final command = invocation.positionalArguments[0] as Command;
        command.execute(project);
      });

      final arrangerViewModel = ArrangerViewModel(project: project)
        ..baseTrackHeight = 40
        ..timeRange = TimeRange(0, 4);
      trackController = TrackController(project);

      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(idAllocatorService, (_, _) => idAllocator),
          overrideService(
            arrangerViewModelService,
            (_, _) => arrangerViewModel,
          ),
          overrideService(trackControllerService, (_, _) => trackController),
        ]),
      );

      for (final track in tracks.values) {
        if (track.type == TrackType.group) {
          processingGraph.restoreGraphFragment(
            trackController.buildTrackMixFragment(track),
          );
        } else {
          track.createAndRegisterNodes(project, idAllocator);
        }
      }

      trackController.rerouteTracks(tracks.keys);

      automationLane = createTrack('Automation Lane', .automationLane)
        ..automationLaneParentTrackId = otherTrack.id;
      tracks[automationLane.id] = automationLane;
      otherTrack.automationLanes.add(automationLane.id);

      clipOnAutomationLane = createClip(
        patternId: automationLanePattern.id,
        trackId: automationLane.id,
        offset: 64,
      );
      arrangementA.clips[clipOnAutomationLane.id] = clipOnAutomationLane;
    });

    tearDown(() {
      ServiceRegistry.removeProject(projectId);
    });

    test('deleteClips removes target clips and orphan patterns', () {
      final result = trackController.deleteClips(
        clipIds: [clipOnGroupOrphan.id, clipOnGroupShared.id, getId()],
      );

      expect(arrangementA.clips[clipOnGroupOrphan.id], isNull);
      expect(arrangementA.clips[clipOnGroupShared.id], isNull);
      expect(arrangementA.clips[clipOnOtherShared.id], isNotNull);
      expect(arrangementA.clips[clipOnChildOrphan.id], isNotNull);

      expect(result.deletedClipIds, {
        clipOnGroupOrphan.id,
        clipOnGroupShared.id,
      });
      expect(result.deletedPatternIds, {orphanPatternA.id});

      expect(sequence.patterns[orphanPatternA.id], isNull);
      expect(sequence.patterns[sharedPattern.id], isNotNull);
      expect(sequence.patterns[orphanPatternB.id], isNotNull);

      verify(project.startUndoGroup()).called(1);
      verify(project.commitUndoGroup()).called(1);
    });

    test('removeTracks removes clips on those tracks and descendants', () {
      trackController.removeTracks([groupTrack.id]);

      expect(arrangementA.clips[clipOnGroupOrphan.id], isNull);
      expect(arrangementA.clips[clipOnGroupShared.id], isNull);
      expect(arrangementA.clips[clipOnChildOrphan.id], isNull);
      expect(arrangementA.clips[clipOnOtherShared.id], isNotNull);

      expect(sequence.patterns[orphanPatternA.id], isNull);
      expect(sequence.patterns[orphanPatternB.id], isNull);
      expect(sequence.patterns[sharedPattern.id], isNotNull);

      expect(tracks[groupTrack.id], isNull);
      expect(tracks[childTrack.id], isNull);
      expect(tracks[otherTrack.id], isNotNull);
      expect(tracks[masterTrack.id], isNotNull);

      verify(project.startUndoGroup()).called(1);
      verify(project.commitUndoGroup()).called(1);
    });

    test('removeAutomationLane removes lane clips and orphan patterns', () {
      trackController.removeAutomationLane(automationLane.id);

      expect(arrangementA.clips[clipOnAutomationLane.id], isNull);
      expect(sequence.patterns[automationLanePattern.id], isNull);
      expect(otherTrack.automationLanes, isEmpty);
      expect(tracks[automationLane.id], isNull);

      verify(project.startUndoGroup()).called(1);
      verify(project.commitUndoGroup()).called(1);
    });
  });
}
