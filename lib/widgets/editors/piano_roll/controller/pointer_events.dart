/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

part of 'piano_roll_controller.dart';

const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;

mixin _PianoRollPointerEventsMixin on _PianoRollController {
  void legacyPointerDown(PianoRollPointerDownEvent event) {
    throw StateError(
      'All piano-roll gestures are handled by the piano-roll state machine.',
    );
  }

  void legacyPointerMove(PianoRollPointerMoveEvent event) {}

  void legacyPointerUp(PianoRollPointerUpEvent event) {}
}
