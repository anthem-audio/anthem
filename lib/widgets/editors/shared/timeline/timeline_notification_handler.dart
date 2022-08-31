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

import 'package:anthem/widgets/editors/shared/timeline/timeline_notifications.dart';
import 'package:flutter/widgets.dart';

class TimelineNotificationHandler extends StatelessWidget {
  final Widget child;

  const TimelineNotificationHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<TimelineNotification>(
      child: child,
      onNotification: (notification) {
        if (notification is TimelineLabelPointerDownNotification) {
          // print("down");
          // print("at ${notification.time} on label with id ${notification.labelID}");
        }
        else if (notification is TimelineLabelPointerMoveNotification) {
          // print("move");
          // print("at ${notification.time} on label with id ${notification.labelID}");
        }
        else if (notification is TimelineLabelPointerUpNotification) {
          // print("up");
          // print("at ${notification.time} on label with id ${notification.labelID}");
        }

        return true;
      },
    );
  }
}
