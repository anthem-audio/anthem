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
import 'package:flutter/widgets.dart';

const trackHeaderContentPadding = EdgeInsets.symmetric(
  horizontal: 4,
  vertical: 4,
);

const _compactContentHeight = 20.0;
const _mediumRegularContentHeight = 44.0;
const _tallRegularContentHeight = 68.0;
const _tallTrackHeightModifier = 1.5;

enum TrackHeaderSize { compact, medium, tall }

/// Vertical geometry for the controls within a track header.
///
/// This is shared with widgets adjacent to the header so their controls can
/// align without duplicating the header's size-tier calculations.
@immutable
class TrackHeaderContentLayout {
  final TrackHeaderSize size;
  final double top;
  final double height;

  const TrackHeaderContentLayout({
    required this.size,
    required this.top,
    required this.height,
  });
}

TrackHeaderContentLayout calculateTrackHeaderContentLayout({
  required double headerHeight,
  required bool isAutomationLane,
}) {
  final mediumThreshold = isAutomationLane
      ? defaultAutomationLaneHeight
      : defaultBaseTrackHeight;
  final tallThreshold = mediumThreshold * _tallTrackHeightModifier;

  final size = switch (headerHeight) {
    final height when height >= tallThreshold => TrackHeaderSize.tall,
    final height when height >= mediumThreshold => TrackHeaderSize.medium,
    _ => TrackHeaderSize.compact,
  };

  final contentHeight = isAutomationLane
      ? switch (size) {
          .compact => _compactContentHeight,
          .medium =>
            defaultAutomationLaneHeight - trackHeaderContentPadding.vertical,
          .tall =>
            defaultAutomationLaneHeight * _tallTrackHeightModifier -
                trackHeaderContentPadding.vertical,
        }
      : switch (size) {
          .compact => _compactContentHeight,
          .medium => _mediumRegularContentHeight,
          .tall => _tallRegularContentHeight,
        };

  return TrackHeaderContentLayout(
    size: size,
    top: (headerHeight - contentHeight) / 2,
    height: contentHeight,
  );
}
