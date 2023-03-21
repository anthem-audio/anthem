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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/main_window/main_window_controller.dart';
import 'package:flutter/widgets.dart';

abstract class PianoRollEvent {
  PianoRollEvent({required this.pianoRollSize});

  final Size pianoRollSize;
}

abstract class PianoRollPointerEvent extends PianoRollEvent {
  PianoRollPointerEvent({
    required this.key,
    required this.offset,
    required this.pointerEvent,
    required this.keyboardModifiers,
    required Size pianoRollSize,
  }) : super(pianoRollSize: pianoRollSize);

  /// MIDI note at cursor. Fraction indicates position in note.
  final double key;

  /// Time at cursor. Fraction indicates position within tick.
  final double offset;

  /// Determines if this is caused by a right click.
  final PointerEvent pointerEvent;

  /// Ctrl, alt and shift key states
  final KeyboardModifiers keyboardModifiers;
}

class PianoRollPointerDownEvent extends PianoRollPointerEvent {
  final ID? noteUnderCursor;
  final bool isResize;

  PianoRollPointerDownEvent({
    required double key,
    required double offset,
    required PointerDownEvent pointerEvent,
    required Size pianoRollSize,
    required KeyboardModifiers keyboardModifiers,
    required this.noteUnderCursor,
    required this.isResize,
  }) : super(
          key: key,
          offset: offset,
          pointerEvent: pointerEvent,
          pianoRollSize: pianoRollSize,
          keyboardModifiers: keyboardModifiers,
        );
}

class PianoRollPointerMoveEvent extends PianoRollPointerEvent {
  PianoRollPointerMoveEvent({
    required double key,
    required double offset,
    required PointerMoveEvent pointerEvent,
    required Size pianoRollSize,
    required KeyboardModifiers keyboardModifiers,
  }) : super(
          key: key,
          offset: offset,
          pointerEvent: pointerEvent,
          pianoRollSize: pianoRollSize,
          keyboardModifiers: keyboardModifiers,
        );
}

class PianoRollPointerUpEvent extends PianoRollPointerEvent {
  PianoRollPointerUpEvent({
    required double key,
    required double offset,
    required PointerUpEvent pointerEvent,
    required Size pianoRollSize,
    required KeyboardModifiers keyboardModifiers,
  }) : super(
          key: key,
          offset: offset,
          pointerEvent: pointerEvent,
          pianoRollSize: pianoRollSize,
          keyboardModifiers: keyboardModifiers,
        );
}

class PianoRollTimeSignatureChangeAddEvent extends PianoRollEvent {
  double offset;

  PianoRollTimeSignatureChangeAddEvent({
    required Size pianoRollSize,
    required this.offset,
  }) : super(pianoRollSize: pianoRollSize);
}
