/*
  Copyright (C) 2022 - 2025 Joshua Wade

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

const minTrackHeight = 29.0;
const maxTrackHeight = 150.0;

/// Gets the actual height of a track in pixels, given what we actually store
/// about the track (base track height & track height modifier)
double calculateTrackHeight(
  double baseTrackHeight,
  double trackHeightModifier,
) {
  return (baseTrackHeight * trackHeightModifier).clamp(
    minTrackHeight,
    maxTrackHeight,
  );
}
