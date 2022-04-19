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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';

class ClipLayoutDelegate extends MultiChildLayoutDelegate {
  double timeViewStart;
  double timeViewEnd;
  List<int> trackIDs;
  double baseTrackHeight;
  Map<int, double> trackHeightModifiers;
  List<int> clipIDs;
  ProjectModel project;
  int arrangementID;
  double verticalScrollPosition;

  ClipLayoutDelegate({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.trackIDs,
    required this.baseTrackHeight,
    required this.trackHeightModifiers,
    required this.clipIDs,
    required this.project,
    required this.arrangementID,
    required this.verticalScrollPosition,
  });

  @override
  void performLayout(Size size) {
    for (final clipID in clipIDs) {
      final clipModel =
          project.song.arrangements[arrangementID]!.clips[clipID]!;

      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: clipModel.offset.toDouble(),
      );

      final width = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: timeViewStart +
            (clipModel.timeView?.width ??
                96 * 4), // TODO: Use width of content as default
      );

      final y = trackIndexToPos(
        trackIndex: trackIDs
            .indexWhere((trackID) => trackID == clipModel.trackID)
            .toDouble(),
        baseTrackHeight: baseTrackHeight,
        trackOrder: trackIDs,
        trackHeightModifiers: trackHeightModifiers,
        scrollPosition: verticalScrollPosition,
      );

      final trackHeight = getTrackHeight(
        baseTrackHeight,
        trackHeightModifiers[clipModel.trackID]!,
      );

      layoutChild(
        clipID,
        BoxConstraints.tight(
          Size(
            (width - 1).clamp(0, double.infinity),
            (trackHeight - 1).clamp(0, double.infinity),
          ),
        ),
      );
      positionChild(clipID, Offset(x + 1, y));
    }
  }

  @override
  bool shouldRelayout(covariant ClipLayoutDelegate oldDelegate) {
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.trackIDs != trackIDs ||
        oldDelegate.baseTrackHeight != baseTrackHeight ||
        oldDelegate.trackHeightModifiers != trackHeightModifiers ||
        oldDelegate.clipIDs != clipIDs ||
        oldDelegate.arrangementID != arrangementID ||
        oldDelegate.verticalScrollPosition != verticalScrollPosition;
  }
}
