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

import 'package:anthem/visualization/ring_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RingBufferDouble behavior', () {
    final buffer = RingBuffer<double>(3);

    expect(buffer.values.length, 0);

    buffer.add(1);
    expect(buffer.values, [1]);

    buffer.add(2);
    expect(buffer.values, [1, 2]);

    buffer.add(3);
    expect(buffer.values, [1, 2, 3]);

    buffer.add(4);
    expect(buffer.values, [2, 3, 4]);

    buffer.add(5);
    expect(buffer.values, [3, 4, 5]);

    buffer.add(6);
    expect(buffer.values, [4, 5, 6]);

    buffer.add(7);
    expect(buffer.values, [5, 6, 7]);

    buffer.reset();
    expect(buffer.values.length, 0);

    buffer.add(1);
    expect(buffer.values, [1]);

    buffer.add(2);
    buffer.add(3);
    buffer.add(4);

    expect(buffer.values, [2, 3, 4]);
  });
}
