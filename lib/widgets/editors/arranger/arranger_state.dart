/*
  Copyright (C) 2022 Joshua Wade

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

part of 'arranger_cubit.dart';

@freezed
class ArrangerState with _$ArrangerState {
  factory ArrangerState({
    required ID projectID,

    required ID? activeArrangementID,
    required List<ID> arrangementIDs,
    required Map<ID, String> arrangementNames,

    // List of track IDs which implicitly encodes track order
    required List<ID> trackIDs,
    // Base track height
    required double baseTrackHeight,
    // Per-track modifier that is multiplied by baseTrackHeight and clamped to
    // get the actual height for each track
    required Map<ID, double> trackHeightModifiers,

    // Total height of the entire scrollable region
    required double scrollAreaHeight,
    // Vertical scroll position, in pixels
    @Default(0) double verticalScrollPosition,

    required List<ID> clipIDs,

    required int ticksPerQuarter,

    @Default(EditorTool.pencil) EditorTool tool,
  }) = _ArrangerState;
}
