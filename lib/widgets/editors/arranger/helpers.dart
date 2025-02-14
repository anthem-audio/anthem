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

import 'package:anthem/helpers/id.dart';

const minTrackHeight = 25.0;
const maxTrackHeight = 150.0;

/// Gets the actual height of a track in pixels, given what we actually store
/// about the track (base track height & track height modifier)
double getTrackHeight(double baseTrackHeight, double trackHeightModifier) {
  return (baseTrackHeight * trackHeightModifier).clamp(
    minTrackHeight,
    maxTrackHeight,
  );
}

double getScrollAreaHeight(
  double baseTrackHeight,
  Map<Id, double> trackHeightModifiers,
) {
  return trackHeightModifiers.entries.fold(
    0,
    (previousValue, element) =>
        previousValue + getTrackHeight(baseTrackHeight, element.value),
  );
}

/// Gets the track index plus a [0 - 1) offset from the top of the track, given
/// a y-offset from the top of the screen and some info about the state of the
/// arranger.
double posToTrackIndex({
  required double yOffset,
  required double baseTrackHeight,
  required List<Id> trackOrder,
  required Map<Id, double> trackHeightModifiers,
  required double scrollPosition,
}) {
  // yOffset relative to scroll area start
  final yScrollAreaOffset = yOffset + scrollPosition;

  if (yScrollAreaOffset < 0) {
    return yScrollAreaOffset /
        baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
  }

  double yPixelPointer = 0;
  double yIndexPointer = 0;

  for (final trackID in trackOrder) {
    final trackHeight = getTrackHeight(
      baseTrackHeight,
      trackHeightModifiers[trackID]!,
    );

    if (yPixelPointer + trackHeight > yScrollAreaOffset) {
      return yIndexPointer + (yScrollAreaOffset - yPixelPointer) / trackHeight;
    }

    yPixelPointer += trackHeight;
    yIndexPointer++;
  }

  return double.infinity;
}

/// Inverse of `posToTrackIndex()`
double trackIndexToPos({
  required double trackIndex,
  required double baseTrackHeight,
  required List<Id> trackOrder,
  required Map<Id, double> trackHeightModifiers,
  required double scrollPosition,
}) {
  double yPixelPointer = -scrollPosition;
  double yIndexPointer = 0;

  for (final trackID in trackOrder) {
    final trackHeight = getTrackHeight(
      baseTrackHeight,
      trackHeightModifiers[trackID]!,
    );

    if (yIndexPointer + 1 > trackIndex) {
      return yPixelPointer + trackHeight * (trackIndex - yIndexPointer);
    }

    yPixelPointer += trackHeight;
    yIndexPointer++;
  }

  return yPixelPointer;
}
