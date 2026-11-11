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

import 'package:anthem/model/project.dart';

class RenderTickRange {
  final int startTick;
  final int endTick;

  const RenderTickRange({required this.startTick, required this.endTick});

  int get durationTicks => endTick - startTick;
  bool get isValid => startTick >= 0 && endTick > startTick;
}

RenderTickRange? activeArrangementContentRenderRange(ProjectModel project) {
  final arrangement = project.sequence.arrangement;
  if (arrangement.clips.isEmpty) {
    return null;
  }

  final endTick = arrangement.clips.values.fold<int>(
    0,
    (endTick, clip) =>
        max(endTick, clip.offset + clip.getWidthFromProject(project)),
  );

  if (endTick <= 0) {
    return null;
  }

  return RenderTickRange(startTick: 0, endTick: endTick);
}

RenderTickRange? activeArrangementLoopRenderRange(ProjectModel project) {
  final loopPoints = project.sequence.arrangement.loopPoints;
  if (loopPoints == null) {
    return null;
  }

  final range = RenderTickRange(
    startTick: loopPoints.start,
    endTick: loopPoints.end,
  );

  return range.isValid ? range : null;
}
