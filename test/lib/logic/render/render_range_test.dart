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

import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activeArrangementContentRenderRange returns null with no content', () {
    final project = ProjectModel.create();

    expect(activeArrangementContentRenderRange(project), isNull);
  });

  test(
    'activeArrangementContentRenderRange uses active arrangement clip ends',
    () {
      final project = ProjectModel.create();
      final arrangement =
          project.sequence.arrangements[project.sequence.activeArrangementID]!;

      final firstPattern = PatternModel(
        idAllocator: project.idAllocator,
        name: 'First',
      )..clipAutoWidth = 96;
      final secondPattern = PatternModel(
        idAllocator: project.idAllocator,
        name: 'Second',
      )..clipAutoWidth = 240;

      project.sequence.patterns[firstPattern.id] = firstPattern;
      project.sequence.patterns[secondPattern.id] = secondPattern;

      arrangement.clips[1] = ClipModel(
        idAllocator: project.idAllocator,
        patternId: firstPattern.id,
        trackId: project.trackOrder.first,
        offset: 192,
      );
      arrangement.clips[2] = ClipModel(
        idAllocator: project.idAllocator,
        patternId: secondPattern.id,
        trackId: project.trackOrder.first,
        offset: 48,
        timeView: TimeViewModel(start: 0, end: 384),
      );

      final range = activeArrangementContentRenderRange(project);

      expect(range?.startTick, equals(0));
      expect(range?.endTick, equals(432));
    },
  );

  test('activeArrangementLoopRenderRange returns valid loop points only', () {
    final project = ProjectModel.create();
    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    expect(activeArrangementLoopRenderRange(project), isNull);

    arrangement.loopPoints = LoopPointsModel(384, 192);
    expect(activeArrangementLoopRenderRange(project), isNull);

    arrangement.loopPoints = LoopPointsModel(96, 384);
    final range = activeArrangementLoopRenderRange(project);

    expect(range?.startTick, equals(96));
    expect(range?.endTick, equals(384));
  });
}
