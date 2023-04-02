/*
  Copyright (C) 2023 Joshua Wade

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
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/widgets.dart';

class ArrangerPointerEvent {
  /// Offset from the start of the arrangement, in ticks
  double offset;

  /// Track index, starting at 0. A value of 2.5 means halfway through the
  /// track with an index of 2.
  double track;

  /// The pointer event that originated this [ArrangerPointerEvent].
  PointerEvent pointerEvent;

  /// Size of the arranger when this event occurred.
  Size arrangerSize;

  /// Ctrl, alt and shift key states.
  KeyboardModifiers keyboardModifiers;

  /// The clip under the cursor during this event, if any. Currently just used
  /// for pointer down events.
  ID? clipUnderCursor;

  ArrangerPointerEvent({
    required this.offset,
    required this.track,
    required this.pointerEvent,
    required this.arrangerSize,
    required this.keyboardModifiers,
    this.clipUnderCursor,
  });
}
