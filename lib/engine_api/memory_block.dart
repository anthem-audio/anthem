/*
  Copyright (C) 2024 Joshua Wade

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

import 'dart:math';

import 'package:flutter/foundation.dart';

/// Modeled after JUCE memory blocks. Allows more efficient queueing of data
/// from the socket connection.
class MemoryBlock {
  Uint8List buffer = Uint8List(0);

  /// Appends the given data onto the end of the buffer.
  void append(Uint8List bytes) {
    final oldBuffer = buffer;
    buffer = Uint8List(oldBuffer.length + bytes.length);

    buffer.setAll(0, oldBuffer);
    buffer.setAll(oldBuffer.length, bytes);
  }

  /// Removes items in the buffer with an index greater than or equal to start,
  /// and less than end.
  void removeRange(int start, int end) {
    final oldBuffer = buffer;
    buffer = Uint8List(max(buffer.length - (end - start), 0));

    if (buffer.isEmpty) return;

    buffer.setAll(0, oldBuffer.sublist(0, start));
    buffer.setAll(start, oldBuffer.sublist(end));
  }
}
