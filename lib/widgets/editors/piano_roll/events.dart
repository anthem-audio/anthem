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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/widgets.dart';

abstract class PianoRollEvent {}

abstract class PianoRollPointerEvent extends PianoRollEvent {
  PianoRollPointerEvent({
    required this.pointerEvent,
    required this.keyboardModifiers,
  });

  /// Determines if this is caused by a right click.
  final PointerEvent pointerEvent;

  /// Ctrl, alt and shift key states.
  final KeyboardModifiers keyboardModifiers;
}

class PianoRollPointerDownEvent extends PianoRollPointerEvent {
  PianoRollPointerDownEvent({
    required PointerDownEvent super.pointerEvent,
    required super.keyboardModifiers,
  });
}

class PianoRollPointerMoveEvent extends PianoRollPointerEvent {
  PianoRollPointerMoveEvent({
    required PointerMoveEvent super.pointerEvent,
    required super.keyboardModifiers,
  });
}

class PianoRollPointerUpEvent extends PianoRollPointerEvent {
  PianoRollPointerUpEvent({
    required super.pointerEvent,
    required super.keyboardModifiers,
  });
}

class PianoRollTimeSignatureChangeAddEvent extends PianoRollEvent {
  double offset;

  PianoRollTimeSignatureChangeAddEvent({required this.offset});
}
