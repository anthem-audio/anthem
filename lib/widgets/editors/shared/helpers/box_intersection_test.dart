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

// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';

void main() {
  test('Box intersection tests', () {
    // Test for line segment intersecting opposing edges
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(5, 1),
        const Point(1, 0),
        const Point(2, 1),
      ),
      isTrue,
    );

    // Test for line segment intersecting neighboring edges
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(3, 3),
        const Point(1, 0),
        const Point(3, 2),
      ),
      isTrue,
    );

    // Test for line segment inside box
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(1, 1),
        const Point(-2, -2),
        const Point(2, 2),
      ),
      isTrue,
    );

    // Test for line segment intersecting a single box edge
    expect(
      lineIntersectsBox(
        const Point(-1, 0),
        const Point(1, 0),
        const Point(0, -1),
        const Point(2, 1),
      ),
      isTrue,
    );

    // Test for line segment intersecting two box edges (corner)
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(2, 2),
        const Point(1, 1),
        const Point(3, 3),
      ),
      isTrue,
    );

    // Test for line segment not intersecting box
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(1, 1),
        const Point(2, 2),
        const Point(3, 3),
      ),
      isFalse,
    );

    // Test for line segment coinciding with a box edge
    expect(
      lineIntersectsBox(
        const Point(0, 0),
        const Point(1, 0),
        const Point(0, 0),
        const Point(1, 1),
      ),
      isTrue,
    );

    // Test for line segment just outside the box
    expect(
      lineIntersectsBox(
        const Point(0, -1),
        const Point(1, -1),
        const Point(0, 0),
        const Point(1, 1),
      ),
      isFalse,
    );
  });

  test('Box intersection tests', () {
    // Test for two boxes intersecting partially
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(2, 2),
        const Point(1, 1),
        const Point(3, 3),
      ),
      isTrue,
    );

    // Test for one box entirely inside another
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(4, 4),
        const Point(1, 1),
        const Point(3, 3),
      ),
      isTrue,
    );

    // Test for two boxes just touching (edge case)
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(1, 1),
        const Point(1, 1),
        const Point(2, 2),
      ),
      isTrue,
    );

    // Test for two boxes not intersecting (separated along x-axis)
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(1, 1),
        const Point(2, 0),
        const Point(3, 1),
      ),
      isFalse,
    );

    // Test for two boxes not intersecting (separated along y-axis)
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(1, 1),
        const Point(0, 2),
        const Point(1, 3),
      ),
      isFalse,
    );

    // Test for two boxes just not touching (edge case)
    expect(
      boxesIntersect(
        const Point(0, 0),
        const Point(1, 1),
        const Point(1.0001, 1.0001),
        const Point(2, 2),
      ),
      isFalse,
    );
  });
}
