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
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
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
      when(trackM.type).thenReturn(TrackType.instrument);
      when(masterTrack.type).thenReturn(TrackType.instrument);

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
      expect(
        projectController.canGroupTracks([trackL.id, masterTrack.id]),
        isFalse,
      );
      expect(projectController.canGroupTracks([masterTrack.id]), isFalse);
    });
  });

  group('insertTrackAt()', () {
    final projectId = getId();

    late MockProjectModel project;
    late ProjectController projectController;

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
      return TrackModel(name: name, color: AnthemColor.randomHue(), type: type);
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

      regularGroup = createTrack('Regular Group', .group);
      regularChildA = createTrack('Regular Child A', .instrument);
      regularChildB = createTrack('Regular Child B', .instrument);
      regularTopA = createTrack('Regular Top A', .instrument);
      regularTopB = createTrack('Regular Top B', .instrument);

      sendGroup = createTrack('Send Group', .group);
      sendChild = createTrack('Send Child', .instrument);
      sendTop = createTrack('Send Top', .instrument);
      masterTrack = createTrack('Master', .instrument);

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

      final arrangerViewModel = ArrangerViewModel(
        project: project,
        baseTrackHeight: 40,
        timeView: TimeRange(0, 4),
      );
      ServiceRegistry.forProject(
        projectId,
      ).register<ArrangerViewModel>(arrangerViewModel);

      when(project.execute(any)).thenAnswer((invocation) {
        final command = invocation.positionalArguments[0] as Command;
        command.execute(project);
      });

      projectController = ProjectController(project, MockProjectViewModel());
    });

    tearDown(() {
      ServiceRegistry.removeProject(projectId);
    });

    test('group anchor inserts at end of group', () {
      final oldChildren = List<Id>.from(regularGroup.childTracks);

      projectController.insertTrackAt(regularGroup.id);

      expect(regularGroup.childTracks.length, equals(oldChildren.length + 1));
      expect(regularGroup.childTracks.take(oldChildren.length), oldChildren);

      final newTrackId = regularGroup.childTracks.last;
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, equals(regularGroup.id));
      expect(newTrack.type, equals(TrackType.instrument));
    });

    test('regular child anchor inserts below within parent group', () {
      final oldChildren = List<Id>.from(regularGroup.childTracks);
      final anchorIndex = oldChildren.indexOf(regularChildA.id);

      projectController.insertTrackAt(regularChildA.id);

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

      projectController.insertTrackAt(regularTopA.id);

      expect(trackOrder.length, equals(oldTrackOrder.length + 1));

      final newTrackId = trackOrder[anchorIndex + 1];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, isNull);

      expect(trackOrder[anchorIndex], equals(regularTopA.id));
      expect(trackOrder[anchorIndex + 2], equals(regularTopB.id));
    });

    test('top-level send anchor inserts below in sendTrackOrder', () {
      final oldSendTrackOrder = List<Id>.from(sendTrackOrder);
      final anchorIndex = oldSendTrackOrder.indexOf(sendTop.id);

      projectController.insertTrackAt(sendTop.id);

      expect(sendTrackOrder.length, equals(oldSendTrackOrder.length + 1));

      final newTrackId = sendTrackOrder[anchorIndex + 1];
      final newTrack = tracks[newTrackId];
      expect(newTrack, isNotNull);
      expect(newTrack!.parentTrackId, isNull);

      expect(sendTrackOrder[anchorIndex], equals(sendTop.id));
      expect(sendTrackOrder[anchorIndex + 2], equals(masterTrack.id));
    });
  });
}
