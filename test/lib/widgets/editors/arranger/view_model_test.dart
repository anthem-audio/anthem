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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ArrangerViewModel createViewModel() {
    final project = ProjectModel()..isHydrated = true;

    return ArrangerViewModel(
      project: project,
      baseTrackHeight: 60,
      timeRange: TimeRange(0, 960),
    );
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
}
