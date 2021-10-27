/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:flutter/widgets.dart';

// Notifications that describe pointer events on notes. How they are handled
// will depend on the current state of the piano roll controller.
class NotePointerNotification extends Notification {
  NotePointerNotification({
    required this.noteID,
    required this.pressed,
    required this.isRightClick,
  });

  final int noteID;
  final bool pressed;
  final bool isRightClick;
}

abstract class PianoRollNotification extends Notification {
  PianoRollNotification({required this.pianoRollSize});

  final Size pianoRollSize;
}

abstract class PianoRollPointerNotification extends PianoRollNotification {
  PianoRollPointerNotification({
    required this.note,
    required this.time,
    required this.event,
    required Size pianoRollSize,
  }) : super(pianoRollSize: pianoRollSize);

  // MIDI note at cursor. Fraction indicates position in note.
  final double note;

  // Time at cursor. Fraction indicates position within tick.
  final double time;

  // Determines if this is caused by a right click.
  final PointerEvent event;
}

class PianoRollPointerDownNotification extends PianoRollPointerNotification {
  PianoRollPointerDownNotification({
    required double note,
    required double time,
    required PointerDownEvent event,
    required Size pianoRollSize,
  }) : super(
          note: note,
          time: time,
          event: event,
          pianoRollSize: pianoRollSize,
        );
}

class PianoRollPointerMoveNotification extends PianoRollPointerNotification {
  PianoRollPointerMoveNotification({
    required double note,
    required double time,
    required PointerMoveEvent event,
    required Size pianoRollSize,
  }) : super(
          note: note,
          time: time,
          event: event,
          pianoRollSize: pianoRollSize,
        );
}

class PianoRollPointerUpNotification extends PianoRollPointerNotification {
  PianoRollPointerUpNotification({
    required double note,
    required double time,
    required PointerUpEvent event,
    required Size pianoRollSize,
  }) : super(
          note: note,
          time: time,
          event: event,
          pianoRollSize: pianoRollSize,
        );
}
