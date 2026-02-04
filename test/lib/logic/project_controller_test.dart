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
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<TrackModel>(),
  MockSpec<ProjectViewModel>(),
])
import 'project_controller_test.mocks.dart';

void main() {
  group('canGroupTracks()', () {
    final projectId = getId();
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

      // Regular tracks: A (group) -> B, C
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
      when(trackB.type).thenReturn(TrackType.instrument);
      when(trackC.type).thenReturn(TrackType.instrument);

      when(
        trackA.childTracks,
      ).thenReturn(AnthemObservableList.of([trackBId, trackCId]));
      when(trackB.childTracks).thenReturn(AnthemObservableList());
      when(trackC.childTracks).thenReturn(AnthemObservableList());

      when(trackA.parentTrackId).thenReturn(null);
      when(trackB.parentTrackId).thenReturn(trackAId);
      when(trackC.parentTrackId).thenReturn(trackAId);

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
      when(trackM.type).thenReturn(TrackType.instrument);
      when(masterTrack.type).thenReturn(TrackType.instrument);

      when(trackL.childTracks).thenReturn(AnthemObservableList.of([trackMId]));
      when(trackM.childTracks).thenReturn(AnthemObservableList());
      when(masterTrack.childTracks).thenReturn(AnthemObservableList());

      when(trackL.parentTrackId).thenReturn(null);
      when(trackM.parentTrackId).thenReturn(trackLId);
      when(masterTrack.parentTrackId).thenReturn(null);

      tracks[trackLId] = trackL;
      tracks[trackMId] = trackM;
      tracks[masterTrackId] = masterTrack;
      sendTrackOrder.addAll([trackLId, masterTrackId]);
    });

    test('Main test', () {
      final projectController = ProjectController(
        project,
        MockProjectViewModel(),
      );

      expect(projectController.canGroupTracks([]), isFalse);

      expect(projectController.canGroupTracks([trackA.id, trackB.id]), isTrue);
      expect(projectController.canGroupTracks([trackB.id, trackC.id]), isTrue);
      expect(
        projectController.canGroupTracks([trackA.id, trackB.id, trackC.id]),
        isTrue,
      );

      expect(projectController.canGroupTracks([trackA.id, trackL.id]), isFalse);
      expect(projectController.canGroupTracks([trackB.id, trackM.id]), isFalse);

      expect(projectController.canGroupTracks([trackL.id, trackM.id]), isTrue);
    });
  });
}
