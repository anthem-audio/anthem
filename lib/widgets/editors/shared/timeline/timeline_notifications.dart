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
import 'package:flutter/widgets.dart';

abstract class TimelineNotification extends Notification {}

abstract class TimelinePointerNotification extends TimelineNotification {
  // Time at cursor. Fraction indicates position within tick.
  final double time;

  TimelinePointerNotification({required this.time}) : super();
}

enum TimelineLabelType { timeSignatureChange }

abstract class TimelineLabelPointerNotification
    extends TimelinePointerNotification {
  final ID labelID;
  final TimelineLabelType labelType;

  TimelineLabelPointerNotification({
    required double time,
    required this.labelID,
    required this.labelType,
  }) : super(time: time);
}

class TimelineLabelPointerDownNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerDownNotification({
    required double time,
    required ID labelID,
    required TimelineLabelType labelType,
  }) : super(
          time: time,
          labelID: labelID,
          labelType: labelType,
        );
}

class TimelineLabelPointerMoveNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerMoveNotification({
    required double time,
    required ID labelID,
    required TimelineLabelType labelType,
  }) : super(
          time: time,
          labelID: labelID,
          labelType: labelType,
        );
}

class TimelineLabelPointerUpNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerUpNotification({
    required double time,
    required ID labelID,
    required TimelineLabelType labelType,
  }) : super(
          time: time,
          labelID: labelID,
          labelType: labelType,
        );
}
