/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class TimelineNotificationHandler extends StatefulWidget {
  final TimelineKind timelineKind;
  final ID? patternID;
  final Widget child;

  const TimelineNotificationHandler({
    Key? key,
    required this.child,
    required this.timelineKind,
    this.patternID,
  }) : super(key: key);

  @override
  State<TimelineNotificationHandler> createState() =>
      _TimelineNotificationHandlerState();
}

class _TimelineNotificationHandlerState
    extends State<TimelineNotificationHandler> {
  double startTime = 0;
  Time snapOffset = 0;
  bool hasMoved = false;

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    return NotificationListener<TimelineNotification>(
      child: widget.child,
      onNotification: (notification) {
        if (notification is TimelineLabelPointerNotification) {
          final timeView = Provider.of<TimeRange>(context, listen: false);
          final pattern = project
              .song.patterns.nonObservableInner[project.song.activePatternID];

          final divisionChanges = getDivisionChanges(
            viewWidthInPixels: notification.viewWidthInPixels,
            snap: AutoSnap(),
            defaultTimeSignature: project.song.defaultTimeSignature,
            timeSignatureChanges: pattern?.timeSignatureChanges ?? [],
            ticksPerQuarter: project.song.ticksPerQuarter,
            timeViewStart: timeView.start,
            timeViewEnd: timeView.end,
          );

          final snappedPos = getSnappedTime(
            rawTime: notification.time.floor() +
                ((notification is TimelineLabelPointerDownNotification)
                    ? 0
                    : startTime.floor()),
            divisionChanges: divisionChanges,
          ).clamp(0, 0x7FFFFFFFFFFFFFFF);

          if (notification is TimelineLabelPointerDownNotification) {
            startTime = notification.time;
            snapOffset = notification.time.floor() - snappedPos;
          } else if (notification is TimelineLabelPointerMoveNotification) {
            hasMoved = true;
            project.execute(
              MoveTimeSignatureChangeCommand(
                project: project,
                timelineKind: TimelineKind.pattern,
                patternID: widget.patternID,
                changeID: notification.labelID,
                newOffset: snappedPos + snapOffset,
              ),
              push: false,
            );
          } else if (notification is TimelineLabelPointerUpNotification) {
            project.execute(
              MoveTimeSignatureChangeCommand(
                project: project,
                timelineKind: TimelineKind.pattern,
                patternID: widget.patternID,
                changeID: notification.labelID,
                oldOffset: startTime.floor(),
                newOffset: snappedPos + snapOffset,
              ),
              push: true,
            );
          }
        }

        return true;
      },
    );
  }
}
