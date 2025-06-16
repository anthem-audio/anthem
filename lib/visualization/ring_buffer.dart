/*
  Copyright (C) 2025 Joshua Wade

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

/// A ring buffer.
///
/// Contains a fixed-size buffer that overwrites old values when full.
class RingBuffer<T> {
  final int _maxSize;
  int _size = 0;
  final List<T?> _buffer;
  int _index = 0;

  RingBuffer(this._maxSize)
    : _buffer = List<T?>.filled(_maxSize, null, growable: false);

  void add(T value) {
    _buffer[_index] = value;
    _index = (_index + 1) % _maxSize;
    _size = min(_size + 1, _maxSize);
  }

  Iterable<T> get values {
    if (_size < _maxSize) {
      return _buffer.take(_size).cast<T>();
    }

    var valuesToTake = _size;

    var iter = _buffer.skip(_index);

    final itemsRemaining = _buffer.length - _index;

    if (valuesToTake <= itemsRemaining) {
      return iter.take(valuesToTake).cast<T>();
    } else {
      valuesToTake -= itemsRemaining;
      return iter.followedBy(_buffer.take(valuesToTake)).cast<T>();
    }
  }

  void reset() {
    _size = 0;
    _index = 0;
  }
}
