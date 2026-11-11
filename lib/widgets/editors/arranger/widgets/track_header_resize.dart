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

import 'package:anthem/widgets/editors/arranger/helpers.dart';

const trackHeaderResizeDeadZoneSize = 8.0;

class TrackHeaderResizeDragState {
  final double pointerOriginY;
  final bool ignoresDeadZone;

  const TrackHeaderResizeDragState({
    required this.pointerOriginY,
    required this.ignoresDeadZone,
  });

  factory TrackHeaderResizeDragState.initial({
    required double pointerY,
    required double initialModifier,
  }) => TrackHeaderResizeDragState(
    pointerOriginY: pointerY,
    ignoresDeadZone: initialModifier == 1,
  );
}

typedef TrackHeaderResizeResult = ({
  double pixelHeight,
  double modifier,
  TrackHeaderResizeDragState state,
});

/// Maps a resize pointer position to a track height and modifier.
///
/// The dead zone around a modifier of 1 makes returning to the default height
/// feel sticky. [state] carries the adjusted pointer origin needed to leave
/// that dead zone without a jump; the calculation itself has no side effects.
TrackHeaderResizeResult calculateTrackHeaderResize({
  required double initialPixelHeight,
  required double initialModifier,
  required double pointerY,
  required bool isSendTrack,
  required TrackHeaderResizeDragState state,
}) {
  assert(initialModifier > 0);

  final direction = isSendTrack ? -1.0 : 1.0;
  var nextState = state;
  var deltaPixels = direction * (pointerY - state.pointerOriginY);

  var rawPixelHeight = _clampTrackHeight(initialPixelHeight + deltaPixels);
  var rawModifier = rawPixelHeight / initialPixelHeight * initialModifier;

  final defaultHeightCrossingOffset =
      initialPixelHeight * (1 / initialModifier - 1);
  var distanceFromDefaultHeight = deltaPixels - defaultHeightCrossingOffset;
  final isWithinDeadZone =
      distanceFromDefaultHeight.abs() <= trackHeaderResizeDeadZoneSize;

  if (state.ignoresDeadZone && !isWithinDeadZone) {
    final pointerOriginOffset =
        distanceFromDefaultHeight.sign *
        trackHeaderResizeDeadZoneSize *
        direction;
    nextState = TrackHeaderResizeDragState(
      pointerOriginY: state.pointerOriginY - pointerOriginOffset,
      ignoresDeadZone: false,
    );

    deltaPixels = direction * (pointerY - nextState.pointerOriginY);
    rawPixelHeight = _clampTrackHeight(initialPixelHeight + deltaPixels);
    rawModifier = rawPixelHeight / initialPixelHeight * initialModifier;
    distanceFromDefaultHeight = deltaPixels - defaultHeightCrossingOffset;
  }

  late final double pixelHeight;
  late final double modifier;

  if (!nextState.ignoresDeadZone && isWithinDeadZone) {
    pixelHeight = _clampTrackHeight(initialPixelHeight / initialModifier);
    modifier = pixelHeight / initialPixelHeight * initialModifier;
  } else if (!nextState.ignoresDeadZone) {
    final effectiveDelta =
        deltaPixels -
        distanceFromDefaultHeight.sign * trackHeaderResizeDeadZoneSize;
    pixelHeight = _clampTrackHeight(initialPixelHeight + effectiveDelta);
    modifier = pixelHeight / initialPixelHeight * initialModifier;
  } else {
    pixelHeight = rawPixelHeight;
    modifier = rawModifier;
  }

  return (pixelHeight: pixelHeight, modifier: modifier, state: nextState);
}

double _clampTrackHeight(double height) =>
    height.clamp(minTrackHeight, maxTrackHeight).toDouble();
