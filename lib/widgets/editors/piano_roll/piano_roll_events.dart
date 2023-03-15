/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

abstract class PianoRollEvent {
  PianoRollEvent({required this.pianoRollSize});

  final Size pianoRollSize;
}

abstract class PianoRollPointerEvent extends PianoRollEvent {
  PianoRollPointerEvent({
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

class PianoRollPointerDownEvent extends PianoRollPointerEvent {
  PianoRollPointerDownEvent({
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

class PianoRollPointerMoveEvent extends PianoRollPointerEvent {
  PianoRollPointerMoveEvent({
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

class PianoRollPointerUpEvent extends PianoRollPointerEvent {
  PianoRollPointerUpEvent({
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

class PianoRollTimeSignatureChangeAddEvent extends PianoRollEvent {
  double time;

  PianoRollTimeSignatureChangeAddEvent({
    required Size pianoRollSize,
    required this.time,
  }) : super(pianoRollSize: pianoRollSize);
}
