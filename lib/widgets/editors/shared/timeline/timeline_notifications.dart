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
  final double viewWidthInPixels;

  TimelinePointerNotification({
    required this.time,
    required this.viewWidthInPixels,
  }) : super();
}

enum TimelineLabelType { timeSignatureChange }

abstract class TimelineLabelPointerNotification
    extends TimelinePointerNotification {
  final ID labelID;
  final TimelineLabelType labelType;

  TimelineLabelPointerNotification({
    required super.time,
    required this.labelID,
    required this.labelType,
    required super.viewWidthInPixels,
  });
}

class TimelineLabelPointerDownNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerDownNotification({
    required super.time,
    required super.labelID,
    required super.labelType,
    required super.viewWidthInPixels,
  });
}

class TimelineLabelPointerMoveNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerMoveNotification({
    required super.time,
    required super.labelID,
    required super.labelType,
    required super.viewWidthInPixels,
  });
}

class TimelineLabelPointerUpNotification
    extends TimelineLabelPointerNotification {
  TimelineLabelPointerUpNotification({
    required super.time,
    required super.labelID,
    required super.labelType,
    required super.viewWidthInPixels,
  });
}
