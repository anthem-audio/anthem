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

// ignore_for_file: unused_local_variable, avoid_print

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/track_controller.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/control_value_visualization.dart';
import 'package:anthem/model/processing_graph/processors/db_meter.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_automation_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableSet;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<AnthemColor>(),
  MockSpec<ArrangerViewModel>(),
])
import 'track_commands_test.mocks.dart';

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

void main() {
  late MockProjectModel project;
  late ProcessingGraphModel processingGraph;
  late _MockEngine mockEngine;
  late ProjectEntityIdAllocator idAllocator;

  setUp(() {
    project = MockProjectModel();
    when(project.id).thenReturn(getProjectId());
    when(project.allocateId()).thenAnswer((_) => getId());
    idAllocator = ProjectEntityIdAllocator(project);
    processingGraph = ProcessingGraphModel.create(masterOutputNodeId: getId());
    when(project.processingGraph).thenReturn(processingGraph);
    mockEngine = _MockEngine(_FakeProcessingGraphApi());
    when(project.engine).thenReturn(mockEngine);
  });

  group('Set track properties', () {
    late TrackModel track;
    late AnthemObservableMap<Id, TrackModel> tracks;
    late AnthemObservableList<Id> trackOrder;

    const oldName = 'My Track';
    const newName = 'My New Track Name';

    late AnthemColor color;

    setUp(() {
      color = MockAnthemColor();
      when(color.hue).thenReturn(0);
      when(color.palette).thenReturn(.normal);

      final trackId = getId();

      track = TrackModel(
        idAllocator: ProjectEntityIdAllocator.test(() => trackId),
        name: oldName,
        color: color,
        type: .normal,
      );

      tracks = AnthemObservableMap.of({trackId: track});
      trackOrder = AnthemObservableList.of([trackId]);

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
    });

    test("Change the track's name", () {
      final command = SetTrackNameCommand(track: track, newName: newName);

      expect(track.name, equals(oldName));

      command.execute(project);
      expect(track.name, equals(newName));

      command.rollback(project);
      expect(track.name, equals(oldName));
    });

    test("Change the track's color", () {
      final command = SetTrackColorCommand(
        track: track,
        newHue: 123,
        newPalette: .bright,
      );

      command.execute(project);
      verify(track.color.hue = 123);
      verify(track.color.palette = .bright);

      command.rollback(project);
      verify(track.color.hue = 0);
      verify(track.color.palette = .normal);
    });
  });

  group('Track group/ungroup and add/remove with groups', () {
    // The track hierarchy here is as follows:
    //
    // normal tracks:
    // - A (group)
    //   - B (group)
    //     - C (instrument)
    //     - D (instrument)
    //   - E (group)
    //     - F (instrument)
    //     - G (instrument)
    //   - H (instrument)
    //   - I (instrument)
    // - J (instrument)
    // - K (instrument)
    //
    // SEND TRACKS:
    // - L (group)
    //   - M (instrument)
    //   - N (instrument)
    // - O (instrument)
    // - P (instrument)
    // - Master (instrument)

    late AnthemObservableMap<Id, TrackModel> tracks;
    late AnthemObservableList<Id> trackOrder;
    late AnthemObservableList<Id> sendTrackOrder;

    late Id trackAId;
    late Id trackBId;
    late Id trackCId;
    late Id trackDId;
    late Id trackEId;
    late Id trackFId;
    late Id trackGId;
    late Id trackHId;
    late Id trackIId;
    late Id trackJId;
    late Id trackKId;
    late Id trackLId;
    late Id trackMId;
    late Id trackNId;
    late Id trackOId;
    late Id trackPId;
    late Id masterTrackId;

    late TrackModel trackA;
    late TrackModel trackB;
    late TrackModel trackC;
    late TrackModel trackD;
    late TrackModel trackE;
    late TrackModel trackF;
    late TrackModel trackG;
    late TrackModel trackH;
    late TrackModel trackI;
    late TrackModel trackJ;
    late TrackModel trackK;
    late TrackModel trackL;
    late TrackModel trackM;
    late TrackModel trackN;
    late TrackModel trackO;
    late TrackModel trackP;
    late TrackModel masterTrack;

    void printTrack(TrackModel track, [String prefix = '']) {
      print('$prefix- ${track.name}');
      for (final childId in track.childTracks) {
        final child = tracks[childId];
        if (child != null) {
          printTrack(child, '  $prefix');
        } else {
          print('  $prefix- NULL');
        }
      }
    }

    /// For debugging, prints the current track state.
    ///
    // ignore: unused_element
    void printTracks() {
      print('Tracks:');
      for (final trackId in trackOrder) {
        final track = tracks[trackId];
        if (track != null) {
          printTrack(track);
        } else {
          print('- NULL');
        }
      }

      print('Send tracks:');
      for (final trackId in sendTrackOrder) {
        final track = tracks[trackId];
        if (track != null) {
          printTrack(track);
        } else {
          print('- NULL');
        }
      }
    }

    setUp(() {
      tracks = AnthemObservableMap();
      trackOrder = AnthemObservableList();
      sendTrackOrder = AnthemObservableList();

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
      when(project.sendTrackOrder).thenReturn(sendTrackOrder);

      (Id, TrackModel) createTrack(
        String name,
        TrackType type,
        bool isSendTrack,
      ) {
        final id = getId();
        final track = TrackModel(
          idAllocator: ProjectEntityIdAllocator.test(() => id),
          name: name,
          color: AnthemColor(hue: 0),
          type: type,
        );

        tracks[id] = track;

        return (id, track);
      }

      final pairA = createTrack('A', .group, false);
      final pairB = createTrack('B', .group, false);
      final pairC = createTrack('C', .normal, false);
      final pairD = createTrack('D', .normal, false);
      final pairE = createTrack('E', .group, false);
      final pairF = createTrack('F', .normal, false);
      final pairG = createTrack('G', .normal, false);
      final pairH = createTrack('H', .normal, false);
      final pairI = createTrack('I', .normal, false);
      final pairJ = createTrack('J', .normal, false);
      final pairK = createTrack('K', .normal, false);
      final pairL = createTrack('L', .group, true);
      final pairM = createTrack('M', .normal, true);
      final pairN = createTrack('N', .normal, true);
      final pairO = createTrack('O', .normal, true);
      final pairP = createTrack('P', .normal, true);
      final pairMaster = createTrack('Master', .normal, true);

      trackAId = pairA.$1;
      trackBId = pairB.$1;
      trackCId = pairC.$1;
      trackDId = pairD.$1;
      trackEId = pairE.$1;
      trackFId = pairF.$1;
      trackGId = pairG.$1;
      trackHId = pairH.$1;
      trackIId = pairI.$1;
      trackJId = pairJ.$1;
      trackKId = pairK.$1;
      trackLId = pairL.$1;
      trackMId = pairM.$1;
      trackNId = pairN.$1;
      trackOId = pairO.$1;
      trackPId = pairP.$1;
      masterTrackId = pairMaster.$1;

      trackA = pairA.$2;
      trackB = pairB.$2;
      trackC = pairC.$2;
      trackD = pairD.$2;
      trackE = pairE.$2;
      trackF = pairF.$2;
      trackG = pairG.$2;
      trackH = pairH.$2;
      trackI = pairI.$2;
      trackJ = pairJ.$2;
      trackK = pairK.$2;
      trackL = pairL.$2;
      trackM = pairM.$2;
      trackN = pairN.$2;
      trackO = pairO.$2;
      trackP = pairP.$2;
      masterTrack = pairMaster.$2;
      masterTrack.isMasterTrack = true;

      trackA.childTracks.addAll([trackBId, trackEId, trackHId, trackIId]);
      trackB.childTracks.addAll([trackCId, trackDId]);
      trackE.childTracks.addAll([trackFId, trackGId]);
      trackL.childTracks.addAll([trackMId, trackNId]);

      trackOrder.addAll([trackAId, trackJId, trackKId]);
      sendTrackOrder.addAll([trackLId, trackOId, trackPId, masterTrackId]);

      for (final track in tracks.values) {
        for (final childTrackId in track.childTracks) {
          tracks[childTrackId]!.parentTrackId = track.id;
        }
      }

      final mockArrangerViewModel = MockArrangerViewModel();
      when(mockArrangerViewModel.selectedTracks).thenReturn(ObservableSet());
      final trackController = TrackController(project);
      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(idAllocatorService, (_, _) => idAllocator),
          overrideService(trackControllerService, (_, _) => trackController),
          overrideService(
            arrangerViewModelService,
            (_, _) => mockArrangerViewModel,
          ),
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
    });

    group('Group/ungroup', () {
      void runBasicGroupTest(bool isForSendTrack, Id id1, Id id2) {
        final trackOrderToUse = isForSendTrack ? sendTrackOrder : trackOrder;

        final mockArrangerViewModel =
            ServiceRegistry.forProject(project.id).arrangerViewModel
                as MockArrangerViewModel;

        final originalTrackOrder = List<Id>.from(trackOrderToUse);

        final trackLen = trackOrderToUse.length;
        final id1Index = trackOrderToUse.indexOf(id1);
        expect(
          tracks[trackOrderToUse[id1Index]]!.type,
          equals(TrackType.normal),
        );

        final command = TrackGroupUngroupCommand.group(
          project: project,
          trackIds: [id1, id2],
        );
        command.execute(project);

        final newGroupTrack = tracks[trackOrderToUse[id1Index]];
        expect(newGroupTrack, isNotNull);
        newGroupTrack!;

        expect(trackOrderToUse.length, equals(trackLen - 1));
        expect(newGroupTrack.type, equals(TrackType.group));
        expect(newGroupTrack.childTracks, hasLength(2));
        expect(newGroupTrack.childTracks[0], equals(id1));
        expect(newGroupTrack.childTracks[1], equals(id2));
        expect(tracks[id1]!.parentTrackId, equals(newGroupTrack.id));
        expect(tracks[id2]!.parentTrackId, equals(newGroupTrack.id));

        verify(mockArrangerViewModel.registerTrack(any)).called(1);
        verifyNever(mockArrangerViewModel.unregisterTrack(any));

        command.rollback(project);

        expect(trackOrderToUse.length, equals(trackLen));
        expect(trackOrderToUse, containsAllInOrder(originalTrackOrder));
        expect(tracks[newGroupTrack.id], isNull);
        expect(tracks[id1]!.parentTrackId, isNull);
        expect(tracks[id2]!.parentTrackId, isNull);

        verifyNever(mockArrangerViewModel.registerTrack(any));
        verify(mockArrangerViewModel.unregisterTrack(any)).called(1);
      }

      void expectTrackHasMixRouting(TrackModel track) {
        expect(track.requireProcessing.utilityNodeId, isNotNull);
        expect(track.requireProcessing.dbMeterNodeId, isNotNull);

        final utilityNodeId = track.requireProcessing.utilityNodeId!;
        final dbMeterNodeId = track.requireProcessing.dbMeterNodeId!;
        final expectedDestination = track.parentTrackId != null
            ? (
                nodeId: tracks[track.parentTrackId]!
                    .requireProcessing
                    .utilityNodeId!,
                portId: UtilityProcessorModel.audioInputPortId,
              )
            : track.isMasterTrack
            ? (
                nodeId: processingGraph.masterOutputNodeId,
                portId: processingGraph
                    .getMasterOutputNode()
                    .audioInputPorts
                    .first
                    .id,
              )
            : (
                nodeId: masterTrack.requireProcessing.utilityNodeId!,
                portId: UtilityProcessorModel.audioInputPortId,
              );

        expect(processingGraph.nodes[utilityNodeId], isNotNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNotNull);

        expect(
          processingGraph.connections.values.where(
            (connection) =>
                connection.sourceNodeId == utilityNodeId &&
                connection.sourcePortId ==
                    UtilityProcessorModel.audioOutputPortId &&
                connection.destinationNodeId == dbMeterNodeId &&
                connection.destinationPortId ==
                    DbMeterProcessorModel.audioInputPortId,
          ),
          hasLength(1),
        );

        expect(
          processingGraph.connections.values.where(
            (connection) =>
                connection.sourceNodeId == utilityNodeId &&
                connection.sourcePortId ==
                    UtilityProcessorModel.audioOutputPortId &&
                connection.destinationNodeId == expectedDestination.nodeId &&
                connection.destinationPortId == expectedDestination.portId,
          ),
          hasLength(1),
        );
      }

      test('Basic track grouping test, normal tracks', () {
        runBasicGroupTest(false, trackJId, trackKId);
      });

      test('Basic track grouping test, send tracks', () {
        runBasicGroupTest(true, trackOId, trackPId);
      });

      test('Grouping adds mix nodes and restores them on undo/redo', () {
        final command = TrackGroupUngroupCommand.group(
          project: project,
          trackIds: [trackJId, trackKId],
        );

        command.execute(project);

        final newGroupTrack = tracks[trackOrder[1]];
        expect(newGroupTrack, isNotNull);
        newGroupTrack!;

        expectTrackHasMixRouting(newGroupTrack);
        expect(
          newGroupTrack.requireProcessing.sequenceNoteProviderNodeId,
          isNull,
        );
        expect(newGroupTrack.requireProcessing.liveEventProviderNodeId, isNull);

        final utilityNodeId = newGroupTrack.requireProcessing.utilityNodeId!;
        final dbMeterNodeId = newGroupTrack.requireProcessing.dbMeterNodeId!;

        command.rollback(project);

        expect(tracks[newGroupTrack.id], isNull);
        expect(processingGraph.nodes[utilityNodeId], isNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNull);

        command.execute(project);

        final restoredGroupTrack = tracks[trackOrder[1]];
        expect(restoredGroupTrack, isNotNull);
        restoredGroupTrack!;

        expect(
          restoredGroupTrack.requireProcessing.utilityNodeId,
          equals(utilityNodeId),
        );
        expect(
          restoredGroupTrack.requireProcessing.dbMeterNodeId,
          equals(dbMeterNodeId),
        );
        expectTrackHasMixRouting(restoredGroupTrack);
      });

      test(
        'Ungroup removes existing group mix nodes and undo restores them',
        () {
          expectTrackHasMixRouting(trackL);

          final utilityNodeId = trackL.requireProcessing.utilityNodeId!;
          final dbMeterNodeId = trackL.requireProcessing.dbMeterNodeId!;

          final command = TrackGroupUngroupCommand.ungroup(
            project: project,
            groupTrack: trackLId,
          );

          command.execute(project);

          expect(tracks[trackLId], isNull);
          expect(processingGraph.nodes[utilityNodeId], isNull);
          expect(processingGraph.nodes[dbMeterNodeId], isNull);

          command.rollback(project);

          expect(tracks[trackLId], isNotNull);
          expect(trackL.requireProcessing.utilityNodeId, equals(utilityNodeId));
          expect(trackL.requireProcessing.dbMeterNodeId, equals(dbMeterNodeId));
          expectTrackHasMixRouting(trackL);
        },
      );

      test(
        "Can't group tracks where some are send tracks and some are normal tracks",
        () {
          expect(() {
            print('throws');
            TrackGroupUngroupCommand.group(
              project: project,
              trackIds: [trackAId, trackOId],
            );
          }, throwsA(anything));
        },
      );

      test('Simple grouping within another group', () {
        final originalTrackOrderLength = trackOrder.length;

        final command = TrackGroupUngroupCommand.group(
          project: project,
          trackIds: [trackCId, trackDId],
        );

        command.execute(project);

        // No tracks added or removed at the top level
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track A has the same children

        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // Track B has replaced the grouped tracks with a parent group track

        expect(trackB.childTracks, hasLength(1));
        expect(trackB.parentTrackId, equals(trackA.id));

        final newGroupTrack = tracks[trackB.childTracks[0]];
        expect(newGroupTrack, isNotNull);
        newGroupTrack!;

        expect(newGroupTrack.childTracks, hasLength(2));
        expect(newGroupTrack.type, equals(TrackType.group));
        expect(newGroupTrack.parentTrackId, equals(trackB.id));

        expect(newGroupTrack.childTracks, hasLength(2));
        expect(newGroupTrack.childTracks[0], equals(trackC.id));
        expect(newGroupTrack.childTracks[1], equals(trackD.id));

        expect(trackC.parentTrackId, equals(newGroupTrack.id));
        expect(trackD.parentTrackId, equals(newGroupTrack.id));

        // Rollback and verify the original state is restored

        command.rollback(project);

        // Top-level track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track A still has the same children
        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // Track B's children are restored to the original C and D
        expect(trackB.childTracks, hasLength(2));
        expect(trackB.childTracks[0], equals(trackC.id));
        expect(trackB.childTracks[1], equals(trackD.id));
        expect(trackB.parentTrackId, equals(trackA.id));

        // C and D point back to B as their parent
        expect(trackC.parentTrackId, equals(trackB.id));
        expect(trackD.parentTrackId, equals(trackB.id));

        // The new group track is removed from the tracks map
        expect(tracks[newGroupTrack.id], isNull);
      });

      test('Grouping non-adjacent children within a group', () {
        final originalTrackOrderLength = trackOrder.length;

        final command = TrackGroupUngroupCommand.group(
          project: project,
          trackIds: [trackEId, trackIId],
        );

        command.execute(project);

        // Top-level track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track A now has 3 children: B, newGroup (at E's old position), H
        expect(trackA.childTracks, hasLength(3));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[2], equals(trackH.id));

        final newGroupTrack = tracks[trackA.childTracks[1]];
        expect(newGroupTrack, isNotNull);
        newGroupTrack!;

        // The new group track is between B and H
        expect(newGroupTrack.type, equals(TrackType.group));
        expect(newGroupTrack.parentTrackId, equals(trackA.id));

        // The new group track contains E and I
        expect(newGroupTrack.childTracks, hasLength(2));
        expect(newGroupTrack.childTracks[0], equals(trackE.id));
        expect(newGroupTrack.childTracks[1], equals(trackI.id));

        // E and I point to the new group as their parent
        expect(trackE.parentTrackId, equals(newGroupTrack.id));
        expect(trackI.parentTrackId, equals(newGroupTrack.id));

        // E still has its original children F and G
        expect(trackE.childTracks, hasLength(2));
        expect(trackE.childTracks[0], equals(trackF.id));
        expect(trackE.childTracks[1], equals(trackG.id));

        // Rollback and verify the original state is restored

        command.rollback(project);

        // Top-level track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track A's children are restored to B, E, H, I
        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // E and I point back to A as their parent
        expect(trackE.parentTrackId, equals(trackA.id));
        expect(trackI.parentTrackId, equals(trackA.id));

        // E still has its original children
        expect(trackE.childTracks, hasLength(2));
        expect(trackE.childTracks[0], equals(trackF.id));
        expect(trackE.childTracks[1], equals(trackG.id));

        // The new group track is removed from the tracks map
        expect(tracks[newGroupTrack.id], isNull);
      });

      test('Ungrouping track E', () {
        final originalTrackOrderLength = trackOrder.length;

        final command = TrackGroupUngroupCommand.ungroup(
          project: project,
          groupTrack: trackEId,
        );

        command.execute(project);

        // Top-level track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track E is removed from the tracks map
        expect(tracks[trackEId], isNull);

        // Track A now has 5 children: B, F, G, H, I
        // F and G replace E at E's former index (1)
        expect(trackA.childTracks, hasLength(5));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackF.id));
        expect(trackA.childTracks[2], equals(trackG.id));
        expect(trackA.childTracks[3], equals(trackH.id));
        expect(trackA.childTracks[4], equals(trackI.id));

        // F and G now point to A as their parent
        expect(trackF.parentTrackId, equals(trackA.id));
        expect(trackG.parentTrackId, equals(trackA.id));

        // Rollback and verify the original state is restored

        command.rollback(project);

        // Top-level track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track E is back in the tracks map
        expect(tracks[trackEId], isNotNull);

        // Track A has the original 4 children: B, E, H, I
        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // E has its original children F and G
        expect(trackE.childTracks, hasLength(2));
        expect(trackE.childTracks[0], equals(trackF.id));
        expect(trackE.childTracks[1], equals(trackG.id));

        // E points to A as its parent
        expect(trackE.parentTrackId, equals(trackA.id));

        // F and G point back to E as their parent
        expect(trackF.parentTrackId, equals(trackE.id));
        expect(trackG.parentTrackId, equals(trackE.id));
      });

      test('Grouping top-level tracks A and K', () {
        final command = TrackGroupUngroupCommand.group(
          project: project,
          trackIds: [trackAId, trackKId],
        );

        command.execute(project);

        // trackOrder loses one entry: [newGroup, J]
        expect(trackOrder, hasLength(2));

        // The new group is at A's original position (index 0)
        final newGroupTrack = tracks[trackOrder[0]];
        expect(newGroupTrack, isNotNull);
        newGroupTrack!;

        expect(newGroupTrack.type, equals(TrackType.group));
        expect(newGroupTrack.parentTrackId, isNull);

        // J remains at index 1
        expect(trackOrder[1], equals(trackJ.id));

        // The new group contains A and K
        expect(newGroupTrack.childTracks, hasLength(2));
        expect(newGroupTrack.childTracks[0], equals(trackA.id));
        expect(newGroupTrack.childTracks[1], equals(trackK.id));

        // A and K point to the new group as their parent
        expect(trackA.parentTrackId, equals(newGroupTrack.id));
        expect(trackK.parentTrackId, equals(newGroupTrack.id));

        // A still has its original children
        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // Rollback and verify the original state is restored

        command.rollback(project);

        // trackOrder restored to [A, J, K]
        expect(trackOrder, hasLength(3));
        expect(trackOrder[0], equals(trackA.id));
        expect(trackOrder[1], equals(trackJ.id));
        expect(trackOrder[2], equals(trackK.id));

        // A and K have no parent
        expect(trackA.parentTrackId, isNull);
        expect(trackK.parentTrackId, isNull);

        // A still has its original children
        expect(trackA.childTracks, hasLength(4));
        expect(trackA.childTracks[0], equals(trackB.id));
        expect(trackA.childTracks[1], equals(trackE.id));
        expect(trackA.childTracks[2], equals(trackH.id));
        expect(trackA.childTracks[3], equals(trackI.id));

        // The new group track is removed from the tracks map
        expect(tracks[newGroupTrack.id], isNull);
      });

      test(
        'Grouping a single top-level normal track wraps it in a new group',
        () {
          final originalTrackOrder = List<Id>.from(trackOrder);
          final mockArrangerViewModel =
              ServiceRegistry.forProject(project.id).arrangerViewModel
                  as MockArrangerViewModel;

          final command = TrackGroupUngroupCommand.group(
            project: project,
            trackIds: [trackJId],
          );

          command.execute(project);

          expect(trackOrder, hasLength(originalTrackOrder.length));
          expect(trackOrder[0], equals(trackA.id));
          expect(trackOrder[2], equals(trackK.id));

          final newGroupTrack = tracks[trackOrder[1]];
          expect(newGroupTrack, isNotNull);
          newGroupTrack!;

          expect(newGroupTrack.type, equals(TrackType.group));
          expect(newGroupTrack.parentTrackId, isNull);
          expect(newGroupTrack.childTracks, hasLength(1));
          expect(newGroupTrack.childTracks[0], equals(trackJ.id));
          expect(trackJ.parentTrackId, equals(newGroupTrack.id));

          verify(mockArrangerViewModel.registerTrack(any)).called(1);
          verifyNever(mockArrangerViewModel.unregisterTrack(any));

          command.rollback(project);

          expect(trackOrder, orderedEquals(originalTrackOrder));
          expect(trackJ.parentTrackId, isNull);
          expect(tracks[newGroupTrack.id], isNull);

          verify(mockArrangerViewModel.unregisterTrack(any)).called(1);
        },
      );

      test(
        'Grouping a single top-level send track wraps it in a new group',
        () {
          final originalSendTrackOrder = List<Id>.from(sendTrackOrder);
          final mockArrangerViewModel =
              ServiceRegistry.forProject(project.id).arrangerViewModel
                  as MockArrangerViewModel;

          final command = TrackGroupUngroupCommand.group(
            project: project,
            trackIds: [trackOId],
          );

          command.execute(project);

          expect(sendTrackOrder, hasLength(originalSendTrackOrder.length));
          expect(sendTrackOrder[0], equals(trackL.id));
          expect(sendTrackOrder[2], equals(trackP.id));
          expect(sendTrackOrder[3], equals(masterTrack.id));

          final newGroupTrack = tracks[sendTrackOrder[1]];
          expect(newGroupTrack, isNotNull);
          newGroupTrack!;

          expect(newGroupTrack.type, equals(TrackType.group));
          expect(newGroupTrack.parentTrackId, isNull);
          expect(newGroupTrack.childTracks, hasLength(1));
          expect(newGroupTrack.childTracks[0], equals(trackO.id));
          expect(trackO.parentTrackId, equals(newGroupTrack.id));

          verify(mockArrangerViewModel.registerTrack(any)).called(1);
          verifyNever(mockArrangerViewModel.unregisterTrack(any));

          command.rollback(project);

          expect(sendTrackOrder, orderedEquals(originalSendTrackOrder));
          expect(trackO.parentTrackId, isNull);
          expect(tracks[newGroupTrack.id], isNull);

          verify(mockArrangerViewModel.unregisterTrack(any)).called(1);
        },
      );

      test('Ungrouping send track L', () {
        final originalTrackOrderLength = trackOrder.length;
        final originalSendTrackOrderLength = sendTrackOrder.length;

        final command = TrackGroupUngroupCommand.ungroup(
          project: project,
          groupTrack: trackLId,
        );

        command.execute(project);

        // normal track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // Track L is removed from the tracks map
        expect(tracks[trackLId], isNull);

        // sendTrackOrder now has M and N in place of L: [M, N, O, P, Master]
        expect(sendTrackOrder, hasLength(originalSendTrackOrderLength + 1));
        expect(sendTrackOrder[0], equals(trackM.id));
        expect(sendTrackOrder[1], equals(trackN.id));
        expect(sendTrackOrder[2], equals(trackO.id));
        expect(sendTrackOrder[3], equals(trackP.id));
        expect(sendTrackOrder[4], equals(masterTrack.id));

        // M and N have no parent (they are now top-level send tracks)
        expect(trackM.parentTrackId, isNull);
        expect(trackN.parentTrackId, isNull);

        // Rollback and verify the original state is restored

        command.rollback(project);

        // normal track order unchanged
        expect(trackOrder, hasLength(originalTrackOrderLength));

        // sendTrackOrder restored to [L, O, P, Master]
        expect(sendTrackOrder, hasLength(originalSendTrackOrderLength));
        expect(sendTrackOrder[0], equals(trackL.id));
        expect(sendTrackOrder[1], equals(trackO.id));
        expect(sendTrackOrder[2], equals(trackP.id));
        expect(sendTrackOrder[3], equals(masterTrack.id));

        // Track L is back in the tracks map
        expect(tracks[trackLId], isNotNull);

        // L has its original children M and N
        expect(trackL.childTracks, hasLength(2));
        expect(trackL.childTracks[0], equals(trackM.id));
        expect(trackL.childTracks[1], equals(trackN.id));

        // L has no parent (top-level send track)
        expect(trackL.parentTrackId, isNull);

        // M and N point back to L as their parent
        expect(trackM.parentTrackId, equals(trackL.id));
        expect(trackN.parentTrackId, equals(trackL.id));
      });
    });

    group('AutomationLaneAddRemoveCommand', () {
      ({TrackModel automationLane, TrackModel parentTrack})
      addUtilityAutomationLane() {
        final utilityNodeId = trackJ.requireProcessing.utilityNodeId!;

        final command = AutomationLaneAddRemoveCommand.add(
          project: project,
          parentTrackId: trackJ.id,
          nodeId: utilityNodeId,
          portId: UtilityProcessorModel.gainPortId,
          name: 'Volume',
        );

        command.execute(project);

        return (
          automationLane: tracks[trackJ.automationLanes.single]!,
          parentTrack: trackJ,
        );
      }

      test(
        'automation lane graph includes control value visualization sink',
        () {
          final utilityNode =
              processingGraph.nodes[trackJ.requireProcessing.utilityNodeId!]!;
          final port = utilityNode.getPortById(
            UtilityProcessorModel.gainPortId,
          );
          port.parameterValue = 0.42;

          final (:automationLane, :parentTrack) = addUtilityAutomationLane();

          final automationProcessing =
              automationLane.requireAutomationProcessing;
          final providerNode = processingGraph
              .nodes[automationProcessing.sequenceAutomationProviderNodeId];
          final visualizationNode = processingGraph
              .nodes[automationProcessing.controlValueVisualizationNodeId];

          expect(providerNode, isNotNull);
          expect(visualizationNode, isNotNull);

          final visualizationProcessor =
              visualizationNode!.processor
                  as ControlValueVisualizationProcessorModel;
          final expectedVisualizationId =
              ControlValueVisualizationProcessorModel.buildVisualizationId(
                nodeId: port.nodeId,
                portId: port.id,
              );

          expect(
            visualizationProcessor.visualizationId,
            equals(expectedVisualizationId),
          );
          expect(
            automationProcessing.getOwnedNodeIds(),
            containsAll([providerNode!.id, visualizationNode.id]),
          );
          expect(parentTrack.automationLanes, contains(automationLane.id));

          final connections = processingGraph.connections.values;
          expect(
            connections.any(
              (connection) =>
                  connection.sourceNodeId == providerNode.id &&
                  connection.sourcePortId ==
                      SequenceAutomationProviderProcessorModel
                          .controlOutputPortId &&
                  connection.destinationNodeId == port.nodeId &&
                  connection.destinationPortId == port.id &&
                  connection.dataType == NodePortDataType.control,
            ),
            isTrue,
          );
          expect(
            connections.any(
              (connection) =>
                  connection.sourceNodeId == providerNode.id &&
                  connection.sourcePortId ==
                      SequenceAutomationProviderProcessorModel
                          .controlOutputPortId &&
                  connection.destinationNodeId == visualizationNode.id &&
                  connection.destinationPortId ==
                      ControlValueVisualizationProcessorModel
                          .controlInputPortId &&
                  connection.dataType == NodePortDataType.control,
            ),
            isTrue,
          );
        },
      );

      test('automation visualization node clears and restores with lane', () {
        final utilityNode =
            processingGraph.nodes[trackJ.requireProcessing.utilityNodeId!]!;
        final port = utilityNode.getPortById(UtilityProcessorModel.gainPortId);
        port.parameterValue = 0.42;

        final command = AutomationLaneAddRemoveCommand.add(
          project: project,
          parentTrackId: trackJ.id,
          nodeId: utilityNode.id,
          portId: UtilityProcessorModel.gainPortId,
          name: 'Volume',
        );

        command.execute(project);

        final automationLane = tracks[trackJ.automationLanes.single]!;
        final visualizationNodeId = automationLane
            .requireAutomationProcessing
            .controlValueVisualizationNodeId;
        final visualizationProcessor =
            processingGraph.nodes[visualizationNodeId]!.processor
                as ControlValueVisualizationProcessorModel;
        final visualizationId = visualizationProcessor.visualizationId;

        expect(visualizationNodeId, isNotNull);
        expect(visualizationId, isNotNull);

        command.rollback(project);

        expect(trackJ.automationLanes, isEmpty);
        expect(processingGraph.nodes[visualizationNodeId], isNull);

        command.execute(project);

        expect(trackJ.automationLanes, hasLength(1));
        final restoredVisualizationNode =
            processingGraph.nodes[visualizationNodeId];
        expect(restoredVisualizationNode, isNotNull);
        expect(
          (restoredVisualizationNode!.processor
                  as ControlValueVisualizationProcessorModel)
              .visualizationId,
          equals(visualizationId),
        );
      });
    });

    group('Add/remove', () {
      List<Object> connectionsMatching({
        required Id sourceNodeId,
        required int sourcePortId,
        required Id destinationNodeId,
        required int destinationPortId,
      }) {
        return processingGraph.connections.values
            .where(
              (connection) =>
                  connection.sourceNodeId == sourceNodeId &&
                  connection.sourcePortId == sourcePortId &&
                  connection.destinationNodeId == destinationNodeId &&
                  connection.destinationPortId == destinationPortId,
            )
            .toList(growable: false);
      }

      test(
        'Device add/remove command adds and restores nodes on undo/redo',
        () {
          final command = DeviceAddRemoveCommand.add(
            project: project,
            trackId: trackC.id,
            device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
          );

          command.execute(project);

          final device = trackC.requireProcessing.devices.single;
          final instrumentNodeId = device.nodeIds.single;
          final sequenceNodeId =
              trackC.requireProcessing.sequenceNoteProviderNodeId;
          final liveEventNodeId =
              trackC.requireProcessing.liveEventProviderNodeId;
          expect(trackC.requireProcessing.devices, hasLength(1));
          expect(trackC.requireProcessing.devices.single.id, equals(device.id));
          expect(sequenceNodeId, isNotNull);
          expect(liveEventNodeId, isNotNull);
          expect(processingGraph.nodes[instrumentNodeId], isNotNull);
          expect(processingGraph.nodes[sequenceNodeId!], isNotNull);
          expect(processingGraph.nodes[liveEventNodeId!], isNotNull);

          final instrumentNode = processingGraph.nodes[instrumentNodeId]!;
          expect(instrumentNode.owner?.trackId, equals(trackC.id));
          expect(instrumentNode.owner?.deviceId, equals(device.id));

          final sequenceNode = processingGraph.nodes[sequenceNodeId]!;
          final liveEventNode = processingGraph.nodes[liveEventNodeId]!;
          expect(sequenceNode.owner?.trackId, equals(trackC.id));
          expect(sequenceNode.owner?.deviceId, isNull);
          expect(liveEventNode.owner?.trackId, equals(trackC.id));
          expect(liveEventNode.owner?.deviceId, isNull);

          final sequenceProcessor =
              sequenceNode.processor as SequenceNoteProviderProcessorModel;
          expect(sequenceProcessor.trackId, equals(trackC.id));

          final instrumentToUtilityConnection = processingGraph
              .connections
              .values
              .where(
                (connection) =>
                    connection.sourceNodeId == instrumentNodeId &&
                    connection.destinationNodeId ==
                        trackC.requireProcessing.utilityNodeId &&
                    connection.sourcePortId ==
                        ToneGeneratorProcessorModel.audioOutputPortId &&
                    connection.destinationPortId ==
                        UtilityProcessorModel.audioInputPortId,
              )
              .toList();
          expect(instrumentToUtilityConnection, hasLength(1));

          final sequenceToInstrumentConnection = processingGraph
              .connections
              .values
              .where(
                (connection) =>
                    connection.sourceNodeId == sequenceNode.id &&
                    connection.destinationNodeId == instrumentNodeId &&
                    connection.sourcePortId ==
                        SequenceNoteProviderProcessorModel.eventOutputPortId &&
                    connection.destinationPortId ==
                        ToneGeneratorProcessorModel.eventInputPortId,
              )
              .toList();
          expect(sequenceToInstrumentConnection, hasLength(1));

          final liveEventToInstrumentConnection = processingGraph
              .connections
              .values
              .where(
                (connection) =>
                    connection.sourceNodeId == liveEventNode.id &&
                    connection.destinationNodeId == instrumentNodeId &&
                    connection.sourcePortId ==
                        LiveEventProviderProcessorModel.eventOutputPortId &&
                    connection.destinationPortId ==
                        ToneGeneratorProcessorModel.eventInputPortId,
              )
              .toList();
          expect(liveEventToInstrumentConnection, hasLength(1));

          command.rollback(project);

          expect(trackC.requireProcessing.devices, isEmpty);
          expect(trackC.requireProcessing.deviceRoutingConnectionIds, isEmpty);
          expect(
            trackC.requireProcessing.sequenceNoteProviderNodeId,
            equals(sequenceNodeId),
          );
          expect(
            trackC.requireProcessing.liveEventProviderNodeId,
            equals(liveEventNodeId),
          );
          expect(processingGraph.nodes[instrumentNodeId], isNull);
          expect(processingGraph.nodes[sequenceNodeId], isNotNull);
          expect(processingGraph.nodes[liveEventNodeId], isNotNull);

          command.execute(project);

          expect(trackC.requireProcessing.devices, hasLength(1));
          expect(trackC.requireProcessing.devices.single.id, equals(device.id));
          expect(
            processingGraph.nodes[instrumentNodeId]?.owner?.trackId,
            equals(trackC.id),
          );
          expect(
            processingGraph.nodes[instrumentNodeId]?.owner?.deviceId,
            equals(device.id),
          );
          expect(
            trackC.requireProcessing.sequenceNoteProviderNodeId,
            equals(sequenceNodeId),
          );
          expect(
            trackC.requireProcessing.liveEventProviderNodeId,
            equals(liveEventNodeId),
          );
          expect(processingGraph.nodes[instrumentNodeId], isNotNull);
          expect(processingGraph.nodes[sequenceNodeId], isNotNull);
          expect(processingGraph.nodes[liveEventNodeId], isNotNull);
        },
      );

      test(
        'Device add/remove command removes and restores nodes on undo/redo',
        () {
          DeviceAddRemoveCommand.add(
            project: project,
            trackId: trackC.id,
            device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
          ).execute(project);

          final device = trackC.requireProcessing.devices.single;
          final instrumentNodeId = device.nodeIds.single;
          final initialRoutingConnectionIds = trackC
              .requireProcessing
              .deviceRoutingConnectionIds
              .toList(growable: false);
          expect(trackC.requireProcessing.devices.single.id, equals(device.id));
          expect(processingGraph.nodes[instrumentNodeId], isNotNull);
          expect(initialRoutingConnectionIds, isNotEmpty);

          final command = DeviceAddRemoveCommand.remove(
            project: project,
            trackId: trackC.id,
            deviceId: device.id,
          );

          command.execute(project);

          expect(trackC.requireProcessing.devices, isEmpty);
          expect(trackC.requireProcessing.deviceRoutingConnectionIds, isEmpty);
          expect(processingGraph.nodes[instrumentNodeId], isNull);
          for (final connectionId in initialRoutingConnectionIds) {
            expect(processingGraph.connections[connectionId], isNull);
          }

          command.rollback(project);

          expect(trackC.requireProcessing.devices.single.id, equals(device.id));
          expect(processingGraph.nodes[instrumentNodeId], isNotNull);
          expect(
            trackC.requireProcessing.deviceRoutingConnectionIds,
            isNotEmpty,
          );
        },
      );

      test('Device add/remove command adds utility devices', () {
        final command = DeviceAddRemoveCommand.add(
          project: project,
          trackId: trackC.id,
          device: DeviceDescriptorForCommand(type: DeviceType.utility),
        );

        command.execute(project);

        final device = trackC.requireProcessing.devices.single;
        final utilityNodeId = device.nodeIds.single;
        final utilityNode = processingGraph.nodes[utilityNodeId]!;
        expect(device.type, equals(DeviceType.utility));
        expect(utilityNode.processor, isA<UtilityProcessorModel>());
        expect(
          device.defaultAudioInputPort?.portId,
          equals(UtilityProcessorModel.audioInputPortId),
        );
        expect(
          device.defaultAudioOutputPort?.portId,
          equals(UtilityProcessorModel.audioOutputPortId),
        );

        command.rollback(project);

        expect(trackC.requireProcessing.devices, isEmpty);
        expect(processingGraph.nodes[utilityNodeId], isNull);
      });

      test('Device changes reassert the track main output route', () {
        final originalMainRoute = processingGraph.connections.values
            .firstWhere(
              (connection) =>
                  connection.sourceNodeId ==
                      trackJ.requireProcessing.utilityNodeId &&
                  connection.sourcePortId ==
                      UtilityProcessorModel.audioOutputPortId &&
                  connection.destinationNodeId ==
                      masterTrack.requireProcessing.utilityNodeId &&
                  connection.destinationPortId ==
                      UtilityProcessorModel.audioInputPortId,
            )
            .id;
        processingGraph.removeConnection(originalMainRoute);

        expect(
          connectionsMatching(
            sourceNodeId: trackJ.requireProcessing.utilityNodeId!,
            sourcePortId: UtilityProcessorModel.audioOutputPortId,
            destinationNodeId: masterTrack.requireProcessing.utilityNodeId!,
            destinationPortId: UtilityProcessorModel.audioInputPortId,
          ),
          isEmpty,
        );

        DeviceAddRemoveCommand.add(
          project: project,
          trackId: trackJ.id,
          device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
        ).execute(project);

        final toneGeneratorNodeId =
            trackJ.requireProcessing.devices.single.nodeIds.single;
        final masterOutputPortId = processingGraph
            .getMasterOutputNode()
            .audioInputPorts
            .first
            .id;

        expect(
          connectionsMatching(
            sourceNodeId: toneGeneratorNodeId,
            sourcePortId: ToneGeneratorProcessorModel.audioOutputPortId,
            destinationNodeId: trackJ.requireProcessing.utilityNodeId!,
            destinationPortId: UtilityProcessorModel.audioInputPortId,
          ),
          hasLength(1),
        );
        expect(
          connectionsMatching(
            sourceNodeId: trackJ.requireProcessing.utilityNodeId!,
            sourcePortId: UtilityProcessorModel.audioOutputPortId,
            destinationNodeId: trackJ.requireProcessing.dbMeterNodeId!,
            destinationPortId: DbMeterProcessorModel.audioInputPortId,
          ),
          hasLength(1),
        );
        expect(
          connectionsMatching(
            sourceNodeId: trackJ.requireProcessing.utilityNodeId!,
            sourcePortId: UtilityProcessorModel.audioOutputPortId,
            destinationNodeId: masterTrack.requireProcessing.utilityNodeId!,
            destinationPortId: UtilityProcessorModel.audioInputPortId,
          ),
          hasLength(1),
        );
        expect(
          connectionsMatching(
            sourceNodeId: masterTrack.requireProcessing.utilityNodeId!,
            sourcePortId: UtilityProcessorModel.audioOutputPortId,
            destinationNodeId: processingGraph.masterOutputNodeId,
            destinationPortId: masterOutputPortId,
          ),
          hasLength(1),
        );
      });

      test('Add track undo/redo restores the same track nodes', () {
        final command = TrackAddRemoveCommand.add(
          project: project,
          tracks: [
            TrackDescriptorForCommand(
              index: 2,
              isSendTrack: false,
              trackType: .normal,
              parentTrackId: trackAId,
            ),
          ],
        );

        command.execute(project);

        final newTrackId = trackA.childTracks[2];
        final newTrack = tracks[newTrackId]!;
        final utilityNodeId = newTrack.requireProcessing.utilityNodeId;
        final dbMeterNodeId = newTrack.requireProcessing.dbMeterNodeId;
        final sequenceNodeId =
            newTrack.requireProcessing.sequenceNoteProviderNodeId;
        final liveEventNodeId =
            newTrack.requireProcessing.liveEventProviderNodeId;
        final utilityToDbMeterConnectionId = processingGraph.connections.values
            .firstWhere(
              (connection) =>
                  connection.sourceNodeId == utilityNodeId &&
                  connection.destinationNodeId == dbMeterNodeId &&
                  connection.sourcePortId ==
                      UtilityProcessorModel.audioOutputPortId &&
                  connection.destinationPortId ==
                      DbMeterProcessorModel.audioInputPortId,
            )
            .id;

        expect(processingGraph.nodes[utilityNodeId], isNotNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNotNull);
        expect(processingGraph.nodes[sequenceNodeId], isNotNull);
        expect(processingGraph.nodes[liveEventNodeId], isNotNull);
        expect(
          processingGraph.connections[utilityToDbMeterConnectionId],
          isNotNull,
        );

        command.rollback(project);

        expect(processingGraph.nodes[utilityNodeId], isNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNull);
        expect(processingGraph.nodes[sequenceNodeId], isNull);
        expect(processingGraph.nodes[liveEventNodeId], isNull);
        expect(
          processingGraph.connections[utilityToDbMeterConnectionId],
          isNull,
        );

        command.execute(project);

        expect(newTrack.requireProcessing.utilityNodeId, equals(utilityNodeId));
        expect(newTrack.requireProcessing.dbMeterNodeId, equals(dbMeterNodeId));
        expect(
          newTrack.requireProcessing.sequenceNoteProviderNodeId,
          equals(sequenceNodeId),
        );
        expect(
          newTrack.requireProcessing.liveEventProviderNodeId,
          equals(liveEventNodeId),
        );
        expect(processingGraph.nodes[utilityNodeId], isNotNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNotNull);
        expect(processingGraph.nodes[sequenceNodeId], isNotNull);
        expect(processingGraph.nodes[liveEventNodeId], isNotNull);
        expect(
          processingGraph.connections[utilityToDbMeterConnectionId],
          isNotNull,
        );
      });

      test('Remove track undo restores captured nodes and connections', () {
        final utilityNodeId = trackC.requireProcessing.utilityNodeId;
        final dbMeterNodeId = trackC.requireProcessing.dbMeterNodeId;
        final utilityToDbMeterConnectionId = processingGraph.connections.values
            .firstWhere(
              (connection) =>
                  connection.sourceNodeId == utilityNodeId &&
                  connection.destinationNodeId == dbMeterNodeId &&
                  connection.sourcePortId ==
                      UtilityProcessorModel.audioOutputPortId &&
                  connection.destinationPortId ==
                      DbMeterProcessorModel.audioInputPortId,
            )
            .id;

        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackCId],
        );

        command.execute(project);

        expect(processingGraph.nodes[utilityNodeId], isNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNull);
        expect(
          processingGraph.connections[utilityToDbMeterConnectionId],
          isNull,
        );

        command.rollback(project);

        expect(processingGraph.nodes[utilityNodeId], isNotNull);
        expect(processingGraph.nodes[dbMeterNodeId], isNotNull);
        expect(
          processingGraph.connections[utilityToDbMeterConnectionId],
          isNotNull,
        );
      });

      test('Remove track captures device, sequence, and live nodes', () {
        final sequenceProviderNodeId =
            trackC.requireProcessing.sequenceNoteProviderNodeId!;
        final liveEventProviderNodeId =
            trackC.requireProcessing.liveEventProviderNodeId!;

        DeviceAddRemoveCommand.add(
          project: project,
          trackId: trackC.id,
          device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
        ).execute(project);
        final deviceNodeId =
            trackC.requireProcessing.devices.single.nodeIds.single;

        final deviceRoutingConnectionIds = trackC
            .requireProcessing
            .deviceRoutingConnectionIds
            .toList(growable: false);

        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackCId],
        );

        command.execute(project);

        expect(
          processingGraph.nodes[trackC.requireProcessing.utilityNodeId],
          isNull,
        );
        expect(
          processingGraph.nodes[trackC.requireProcessing.dbMeterNodeId],
          isNull,
        );
        expect(processingGraph.nodes[deviceNodeId], isNull);
        expect(processingGraph.nodes[sequenceProviderNodeId], isNull);
        expect(processingGraph.nodes[liveEventProviderNodeId], isNull);
        for (final connectionId in deviceRoutingConnectionIds) {
          expect(processingGraph.connections[connectionId], isNull);
        }

        command.rollback(project);

        expect(
          processingGraph.nodes[trackC.requireProcessing.utilityNodeId],
          isNotNull,
        );
        expect(
          processingGraph.nodes[trackC.requireProcessing.dbMeterNodeId],
          isNotNull,
        );
        expect(processingGraph.nodes[deviceNodeId], isNotNull);
        expect(processingGraph.nodes[sequenceProviderNodeId], isNotNull);
        expect(processingGraph.nodes[liveEventProviderNodeId], isNotNull);
        for (final connectionId in deviceRoutingConnectionIds) {
          expect(processingGraph.connections[connectionId], isNotNull);
        }
      });

      test('Add a track to a group parent', () {
        final originalChildCount = trackA.childTracks.length;
        final originalTracksCount = tracks.length;

        final command = TrackAddRemoveCommand.add(
          project: project,
          tracks: [
            TrackDescriptorForCommand(
              index: 2,
              isSendTrack: false,
              trackType: .normal,
              parentTrackId: trackAId,
            ),
          ],
        );

        command.execute(project);

        // Track A now has one more child
        expect(trackA.childTracks, hasLength(originalChildCount + 1));
        // The new track was inserted at index 2
        final newTrackId = trackA.childTracks[2];
        final newTrack = tracks[newTrackId];
        expect(newTrack, isNotNull);
        expect(newTrack!.parentTrackId, equals(trackAId));
        expect(newTrack.type, equals(TrackType.normal));
        // Total tracks increased by only the new track.
        expect(tracks, hasLength(originalTracksCount + 1));
        // Top-level order unchanged
        expect(trackOrder, hasLength(3));

        // Rollback
        command.rollback(project);

        expect(trackA.childTracks, hasLength(originalChildCount));
        expect(tracks, hasLength(originalTracksCount));
        expect(tracks[newTrackId], isNull);
      });

      test('Add a track to a group parent at end (no index)', () {
        final originalChildCount = trackB.childTracks.length;

        final command = TrackAddRemoveCommand.add(
          project: project,
          tracks: [
            TrackDescriptorForCommand(
              isSendTrack: false,
              trackType: .normal,
              parentTrackId: trackBId,
            ),
          ],
        );

        command.execute(project);

        // Track B now has one more child at the end
        expect(trackB.childTracks, hasLength(originalChildCount + 1));
        final newTrackId = trackB.childTracks.last;
        expect(tracks[newTrackId]!.parentTrackId, equals(trackBId));

        command.rollback(project);

        expect(trackB.childTracks, hasLength(originalChildCount));
        expect(tracks[newTrackId], isNull);
      });

      test('Throws when adding to a non-group parent', () {
        expect(
          () => TrackAddRemoveCommand.add(
            project: project,
            tracks: [
              TrackDescriptorForCommand(
                isSendTrack: false,
                trackType: .normal,
                parentTrackId: trackCId, // C is an instrument, not a group
              ),
            ],
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('Remove a top-level group track removes all descendants', () {
        final originalTracksCount = tracks.length;

        // Track A contains B, C, D, E, F, G, H, I (8 descendants)
        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackAId],
        );

        command.execute(project);

        // Track A and all its descendants are removed from the tracks map
        expect(tracks[trackAId], isNull);
        expect(tracks[trackBId], isNull);
        expect(tracks[trackCId], isNull);
        expect(tracks[trackDId], isNull);
        expect(tracks[trackEId], isNull);
        expect(tracks[trackFId], isNull);
        expect(tracks[trackGId], isNull);
        expect(tracks[trackHId], isNull);
        expect(tracks[trackIId], isNull);

        // Track A removed from trackOrder
        expect(trackOrder, hasLength(2));
        expect(trackOrder[0], equals(trackJId));
        expect(trackOrder[1], equals(trackKId));

        // Total tracks decreased by 9 (A + 8 descendants)
        expect(tracks, hasLength(originalTracksCount - 9));

        // Rollback restores everything
        command.rollback(project);

        expect(tracks[trackAId], isNotNull);
        expect(tracks[trackBId], isNotNull);
        expect(tracks[trackCId], isNotNull);
        expect(tracks[trackDId], isNotNull);
        expect(tracks[trackEId], isNotNull);
        expect(tracks[trackFId], isNotNull);
        expect(tracks[trackGId], isNotNull);
        expect(tracks[trackHId], isNotNull);
        expect(tracks[trackIId], isNotNull);
        expect(tracks, hasLength(originalTracksCount));
        expect(trackOrder, hasLength(3));
        expect(trackOrder[0], equals(trackAId));

        // Verify the child hierarchy is preserved
        expect(trackA.childTracks, hasLength(4));
        expect(trackB.childTracks, hasLength(2));
        expect(trackE.childTracks, hasLength(2));
      });

      test(
        'Remove nested group track removes it from parent and clears descendants',
        () {
          final originalTracksCount = tracks.length;
          final originalAChildCount = trackA.childTracks.length;

          // Track E is inside A, and contains F and G
          final command = TrackAddRemoveCommand.remove(
            project: project,
            ids: [trackEId],
          );

          command.execute(project);

          // E, F, G removed from tracks map
          expect(tracks[trackEId], isNull);
          expect(tracks[trackFId], isNull);
          expect(tracks[trackGId], isNull);
          expect(tracks, hasLength(originalTracksCount - 3));

          // E removed from A's child list
          expect(trackA.childTracks, hasLength(originalAChildCount - 1));
          expect(trackA.childTracks.contains(trackEId), isFalse);

          // Top-level order unchanged
          expect(trackOrder, hasLength(3));

          // Rollback
          command.rollback(project);

          expect(tracks[trackEId], isNotNull);
          expect(tracks[trackFId], isNotNull);
          expect(tracks[trackGId], isNotNull);
          expect(tracks, hasLength(originalTracksCount));
          expect(trackA.childTracks, hasLength(originalAChildCount));
          expect(trackA.childTracks.contains(trackEId), isTrue);
        },
      );

      test(
        'Removing parent and child together only removes parent from tree',
        () {
          final originalTracksCount = tracks.length;

          // Pass both A (parent) and B (child of A). B should be filtered out
          // since removing A implicitly removes B.
          final command = TrackAddRemoveCommand.remove(
            project: project,
            ids: [trackAId, trackBId],
          );

          command.execute(project);

          // All of A's subtree is removed
          expect(tracks[trackAId], isNull);
          expect(tracks[trackBId], isNull);
          expect(tracks[trackCId], isNull);
          expect(tracks[trackDId], isNull);
          expect(tracks[trackEId], isNull);
          expect(tracks[trackFId], isNull);
          expect(tracks[trackGId], isNull);
          expect(tracks[trackHId], isNull);
          expect(tracks[trackIId], isNull);

          // Only A was removed from trackOrder (not B, since B was never there)
          expect(trackOrder, hasLength(2));
          expect(trackOrder[0], equals(trackJId));
          expect(trackOrder[1], equals(trackKId));

          expect(tracks, hasLength(originalTracksCount - 9));

          // Rollback
          command.rollback(project);

          expect(tracks[trackAId], isNotNull);
          expect(tracks[trackBId], isNotNull);
          expect(tracks, hasLength(originalTracksCount));
          expect(trackOrder, hasLength(3));
        },
      );

      test('Remove send group track and its descendants', () {
        final originalTracksCount = tracks.length;

        // Track L is a send group containing M and N
        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackLId],
        );

        command.execute(project);

        expect(tracks[trackLId], isNull);
        expect(tracks[trackMId], isNull);
        expect(tracks[trackNId], isNull);
        expect(tracks, hasLength(originalTracksCount - 3));

        expect(sendTrackOrder.contains(trackLId), isFalse);
        expect(sendTrackOrder, hasLength(3)); // O, P, Master

        // Rollback
        command.rollback(project);

        expect(tracks[trackLId], isNotNull);
        expect(tracks[trackMId], isNotNull);
        expect(tracks[trackNId], isNotNull);
        expect(tracks, hasLength(originalTracksCount));
        expect(sendTrackOrder, hasLength(4));
        expect(sendTrackOrder[0], equals(trackLId));
      });

      test('Throws when trying to remove master track', () {
        expect(
          () => TrackAddRemoveCommand.remove(
            project: project,
            ids: [masterTrackId],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('master track'),
            ),
          ),
        );
      });

      test('Remove a leaf track from inside a group', () {
        final originalTracksCount = tracks.length;
        final originalBChildCount = trackB.childTracks.length;

        // Track C is a leaf inside group B
        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackCId],
        );

        command.execute(project);

        expect(tracks[trackCId], isNull);
        expect(tracks, hasLength(originalTracksCount - 1));
        expect(trackB.childTracks, hasLength(originalBChildCount - 1));
        expect(trackB.childTracks.contains(trackCId), isFalse);

        // Rollback
        command.rollback(project);

        expect(tracks[trackCId], isNotNull);
        expect(tracks, hasLength(originalTracksCount));
        expect(trackB.childTracks, hasLength(originalBChildCount));
        expect(trackB.childTracks.contains(trackCId), isTrue);
      });

      test('Removing distant ancestor and descendant filters correctly', () {
        // Pass A (root) and C (grandchild of A). Only A should be processed.
        final command = TrackAddRemoveCommand.remove(
          project: project,
          ids: [trackAId, trackCId],
        );

        command.execute(project);

        // Everything under A is gone
        expect(tracks[trackAId], isNull);
        expect(tracks[trackCId], isNull);
        expect(tracks[trackBId], isNull);

        expect(trackOrder, hasLength(2));

        command.rollback(project);

        expect(tracks[trackAId], isNotNull);
        expect(tracks[trackCId], isNotNull);
        expect(trackOrder, hasLength(3));
      });
    });
  });
}
