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
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_project.dart';

void main() {
  ArrangerViewModel createViewModel() {
    final project = createTestProject(includeSequence: false);

    return ArrangerViewModel(project: project);
  }

  group('ArrangerViewModel hitTestContent', () {
    test('prefers end handle when start and end resize handles overlap', () {
      final viewModel = createViewModel();

      viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: 101, type: ResizeAreaType.start),
      );
      viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: 101, type: ResizeAreaType.end),
      );

      final content = viewModel.hitTestContent(const Offset(120, 20));

      expect(content.resizeHandle, isNotNull);
      expect(content.resizeHandle!.metadata.type, ResizeAreaType.end);
    });

    test('keeps clip match priority over a non-matching end resize handle', () {
      final viewModel = createViewModel();

      viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: 101,
      );
      viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: 102, type: ResizeAreaType.end),
      );
      viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: 101, type: ResizeAreaType.start),
      );

      final content = viewModel.hitTestContent(const Offset(120, 20));

      expect(content.clip, isNotNull);
      expect(content.clip!.annotation.metadata, 101);
      expect(content.resizeHandle, isNotNull);
      expect(content.resizeHandle!.metadata.id, 101);
      expect(content.resizeHandle!.metadata.type, ResizeAreaType.start);
    });

    test('prefers automation point handles over tension handles', () {
      final viewModel = createViewModel();
      const handleRect = Rect.fromLTWH(116, 16, 16, 16);

      viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 80, 45),
        metadata: 101,
      );
      viewModel.visibleAutomationHandles.add(
        rect: handleRect,
        metadata: AutomationHandleAnnotation(
          clipId: 101,
          kind: AutomationHandleKind.point,
          pointIndex: 0,
          pointId: 900,
          center: handleRect.center,
        ),
      );
      viewModel.visibleAutomationHandles.add(
        rect: handleRect,
        metadata: AutomationHandleAnnotation(
          clipId: 101,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: 901,
          center: handleRect.center,
        ),
      );

      final content = viewModel.hitTestContent(const Offset(120, 20));

      expect(content.automationHandle, isNotNull);
      expect(
        content.automationHandle!.metadata.kind,
        AutomationHandleKind.point,
      );
      expect(content.automationHandle!.metadata.pointId, 900);
    });
  });

  test('owns its default time range', () {
    final firstViewModel = createViewModel();
    final secondViewModel = createViewModel();
    final secondStart = secondViewModel.timeRange.start;

    expect(
      identical(firstViewModel.timeRange, secondViewModel.timeRange),
      false,
    );

    firstViewModel.timeRange.start++;
    expect(secondViewModel.timeRange.start, secondStart);
  });

  test('group and automation expansion remain independent', () {
    const groupId = 1;
    const automationLaneId = 2;
    const nestedGroupId = 3;
    const childTrackId = 4;
    final project = createTestProject(
      includeSequence: false,
      tracks: const [
        TestProjectTrack(
          id: groupId,
          name: 'Group',
          type: TrackType.group,
          childTracks: [nestedGroupId],
          automationLanes: [automationLaneId],
        ),
        TestProjectTrack(
          id: automationLaneId,
          name: 'Automation lane',
          type: TrackType.automationLane,
          automationLaneParentTrackId: groupId,
        ),
        TestProjectTrack(
          id: nestedGroupId,
          name: 'Nested group',
          type: TrackType.group,
          childTracks: [childTrackId],
          parentTrackId: groupId,
        ),
        TestProjectTrack(
          id: childTrackId,
          name: 'Child',
          parentTrackId: nestedGroupId,
        ),
      ],
      trackOrder: const [groupId],
    );
    final viewModel = ArrangerViewModel(project: project);
    viewModel.automationExpandedByTrackId[groupId] = true;

    Iterable<Id> visibleTrackIds() => viewModel
        .getVisibleTrackRows()
        .whereType<ProjectTrackRow>()
        .map((row) => row.trackId);

    expect(visibleTrackIds(), [
      groupId,
      automationLaneId,
      nestedGroupId,
      childTrackId,
    ]);

    viewModel.setGroupExpanded(nestedGroupId, false);
    expect(visibleTrackIds(), [groupId, automationLaneId, nestedGroupId]);

    viewModel.setGroupExpanded(groupId, false);
    expect(visibleTrackIds(), [groupId, automationLaneId]);

    viewModel.setGroupExpanded(groupId, true);
    expect(visibleTrackIds(), [groupId, automationLaneId, nestedGroupId]);
    expect(viewModel.isGroupExpanded(nestedGroupId), isFalse);
  });

  test('real and phantom automation lanes share compact zoom behavior', () {
    const parentWithLaneId = 1;
    const automationLaneId = 2;
    const parentWithPhantomId = 3;
    final project = createTestProject(
      includeSequence: false,
      tracks: const [
        TestProjectTrack(
          id: parentWithLaneId,
          name: 'Track with lane',
          automationLanes: [automationLaneId],
        ),
        TestProjectTrack(
          id: automationLaneId,
          name: 'Automation lane',
          type: TrackType.automationLane,
          automationLaneParentTrackId: parentWithLaneId,
        ),
        TestProjectTrack(
          id: parentWithPhantomId,
          name: 'Track with phantom lane',
        ),
      ],
      trackOrder: const [parentWithLaneId, parentWithPhantomId],
    );
    final viewModel = ArrangerViewModel(project: project);
    viewModel.automationExpandedByTrackId[parentWithLaneId] = true;
    viewModel.automationExpandedByTrackId[parentWithPhantomId] = true;

    final rows = viewModel.getVisibleTrackRows().toList();

    expect(rows.map((row) => row.rowKind), [
      TrackRowKind.track,
      TrackRowKind.automationLane,
      TrackRowKind.track,
      TrackRowKind.automationLane,
    ]);
    expect(rows[1], isA<ProjectTrackRow>());
    expect(rows[3], isA<PhantomAutomationTrackRow>());

    viewModel.refreshTrackLayout(0);
    expect(
      viewModel.trackLayout.rowLayouts.map(
        (layout) => layout.contentSpan.height,
      ),
      [defaultBaseTrackHeight, 42, defaultBaseTrackHeight, 42],
    );

    viewModel.baseTrackHeight = defaultBaseTrackHeight * 2;
    viewModel.refreshTrackLayout(0);
    expect(
      viewModel.trackLayout.rowLayouts.map(
        (layout) => layout.contentSpan.height,
      ),
      [defaultBaseTrackHeight * 2, 84, defaultBaseTrackHeight * 2, 84],
    );
  });
}
