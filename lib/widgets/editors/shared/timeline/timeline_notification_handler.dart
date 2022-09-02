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

import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline_notifications.dart';
import 'package:anthem/widgets/project/project_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectCubit, ProjectState>(
      builder: (projectCubit, projectState) {
        final project = Store.instance.projects[projectState.id]!;

        return NotificationListener<TimelineNotification>(
          child: widget.child,
          onNotification: (notification) {
            if (notification is TimelineLabelPointerDownNotification) {
              startTime = notification.time;
            } else if (notification is TimelineLabelPointerMoveNotification) {
              project.execute(
                MoveTimeSignatureChangeCommand(
                  project: project,
                  timelineKind: TimelineKind.pattern,
                  patternID: widget.patternID,
                  changeID: notification.labelID,
                  newOffset: notification.time.floor(),
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
                  newOffset: notification.time.floor(),
                ),
                push: true,
              );
            }

            return true;
          },
        );
      },
    );
  }
}
