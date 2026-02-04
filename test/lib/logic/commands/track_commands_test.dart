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
    // - Master Track (as of writing, a special master track does not exist, but
    //   it should)

    late MockProjectModel projectModel;
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
    late TrackModel masterTrack;

    setUp(() {
      tracks = AnthemObservableMap();
      trackOrder = AnthemObservableList();
      sendTrackOrder = AnthemObservableList();

      when(project.tracks).thenReturn(tracks);
      when(project.trackOrder).thenReturn(trackOrder);
      when(project.sendTrackOrder).thenReturn(sendTrackOrder);

      (Id, TrackModel) createTrack(TrackType type, bool isSendTrack) {
        final id = getId();
        final track = TrackModel(name: '', color: MockAnthemColor(), type: type)
          ..id = id;

        if (isSendTrack) {
          sendTrackOrder.add(id);
        } else {
          trackOrder.add(id);
        }

        tracks[id] = track;

        return (id, track);
      }

      final pairA = createTrack(.group, false);
      final pairB = createTrack(.group, false);
      final pairC = createTrack(.instrument, false);
      final pairD = createTrack(.instrument, false);
      final pairE = createTrack(.group, false);
      final pairF = createTrack(.instrument, false);
      final pairG = createTrack(.instrument, false);
      final pairH = createTrack(.instrument, false);
      final pairI = createTrack(.instrument, false);
      final pairJ = createTrack(.instrument, false);
      final pairK = createTrack(.instrument, false);
      final pairL = createTrack(.group, true);
      final pairM = createTrack(.instrument, true);
      final pairN = createTrack(.instrument, true);
      final pairO = createTrack(.instrument, true);
      final pairMaster = createTrack(.instrument, true);

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
      masterTrack = pairMaster.$2;

      trackA.childTracks.addAll([trackBId, trackEId, trackHId, trackIId]);
      trackB.childTracks.addAll([trackCId, trackDId]);
      trackE.childTracks.addAll([trackFId, trackGId]);
      trackL.childTracks.addAll([trackMId, trackOId]);

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

    test('Grouping tracks base track list (not already in group)', () {
      final trackLen = trackOrder.length;
      final jIndex = trackOrder.indexOf(trackJId);
      expect(tracks[trackOrder[jIndex]]!.type, equals(TrackType.instrument));

      final command = TrackGroupUngroupCommand.group(
        project: project,
        trackIds: [trackJId, trackKId],
      );
      command.execute(project);

      final newGroupTrack = tracks[trackOrder[jIndex]]!;

      expect(trackOrder.length, equals(trackLen - 1));
      expect(newGroupTrack.type, equals(TrackType.group));
      expect(newGroupTrack.childTracks, hasLength(2));
      expect(newGroupTrack.childTracks[0], equals(trackJId));
      expect(newGroupTrack.childTracks[1], equals(trackKId));
    });
  });
}
