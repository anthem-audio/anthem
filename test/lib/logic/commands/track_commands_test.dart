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
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<AnthemColor>(),
  MockSpec<ProjectViewModel>(),
  MockSpec<ArrangerViewModel>(),
])
import 'track_commands_test.mocks.dart';

void main() {
  late MockProjectModel project;

  setUp(() {
    project = MockProjectModel();
    when(project.id).thenReturn(getId());
  });

  group('Set track properties', () {
    late TrackModel track;
    late AnthemObservableMap<String, TrackModel> tracks;
    late AnthemObservableList<String> trackOrder;

    const oldName = 'My Track';
    const newName = 'My New Track Name';

    late AnthemColor color;

    setUp(() {
      color = MockAnthemColor();
      when(color.hue).thenReturn(0);
      when(color.palette).thenReturn(.normal);

      final trackId = getId();

      track = TrackModel(name: oldName, color: color, type: .instrument)
        ..id = trackId;

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

  group('Track group/ungroup', () {
    // The track hierarchy here is as follows:
    //
    // REGULAR TRACKS:
    // - A
    //   - B
    //     - C
    //     - D
    //   - E
    //     - F
    //     - G
    //   - H
    //   - I
    // - J
    // - K
    //
    // SEND TRACKS:
    // - L
    //   - M
    //   - N
    // - O
    // - P
    // - Master Track (as of writing, a special master track does not exist, but
    //   it should)

    late AnthemObservableMap<String, TrackModel> tracks;
    late AnthemObservableList<String> trackOrder;
    late AnthemObservableList<String> sendTrackOrder;

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
          name: name,
          color: MockAnthemColor(),
          type: type,
        )..id = id;

        tracks[id] = track;

        return (id, track);
      }

      final pairA = createTrack('A', .group, false);
      final pairB = createTrack('B', .group, false);
      final pairC = createTrack('C', .instrument, false);
      final pairD = createTrack('D', .instrument, false);
      final pairE = createTrack('E', .group, false);
      final pairF = createTrack('F', .instrument, false);
      final pairG = createTrack('G', .instrument, false);
      final pairH = createTrack('H', .instrument, false);
      final pairI = createTrack('I', .instrument, false);
      final pairJ = createTrack('J', .instrument, false);
      final pairK = createTrack('K', .instrument, false);
      final pairL = createTrack('L', .group, true);
      final pairM = createTrack('M', .instrument, true);
      final pairN = createTrack('N', .instrument, true);
      final pairO = createTrack('O', .instrument, true);
      final pairP = createTrack('P', .instrument, true);
      final pairMaster = createTrack('Master', .instrument, true);

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

      final serviceRegistry = ServiceRegistry.forProject(project.id);
      serviceRegistry.register(
        ProjectController(project, MockProjectViewModel()),
      );
      serviceRegistry.register<ArrangerViewModel>(MockArrangerViewModel());
    });

    void runBasicGroupTest(bool isForSendTrack, Id id1, Id id2) {
      final trackOrderToUse = isForSendTrack ? sendTrackOrder : trackOrder;

      final mockArrangerViewModel =
          ServiceRegistry.forProject(project.id).arrangerViewModel
              as MockArrangerViewModel;

      final originalTrackOrder = List<String>.from(trackOrderToUse);

      final trackLen = trackOrderToUse.length;
      final id1Index = trackOrderToUse.indexOf(id1);
      expect(
        tracks[trackOrderToUse[id1Index]]!.type,
        equals(TrackType.instrument),
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

    test('Basic track grouping test, regular tracks', () {
      runBasicGroupTest(false, trackJId, trackKId);
    });

    test('Basic track grouping test, send tracks', () {
      runBasicGroupTest(true, trackOId, trackPId);
    });

    test(
      "Can't group tracks where some are send tracks and some are regular tracks",
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
  });
}
