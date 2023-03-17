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

import 'dart:math';

/// Checks if point q lies on the line segment formed by points p and r.
bool _onSegment(Point p, Point q, Point r) {
  return q.x <= max(p.x, r.x) &&
      q.x >= min(p.x, r.x) &&
      q.y <= max(p.y, r.y) &&
      q.y >= min(p.y, r.y);
}

/// Returns the orientation of the triplet (p, q, r).
/// 0: Collinear
/// 1: Clockwise
/// 2: Counterclockwise
int _orientation(Point p, Point q, Point r) {
  final val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);

  if (val == 0) return 0;
  return (val > 0) ? 1 : 2;
}

/// Checks if the line segment bounded by [x1, x2] intersects with the line
/// segment bounded by [y1, y2].
bool _intersects(Point x1, Point x2, Point y1, Point y2) {
  final o1 = _orientation(x1, x2, y1);
  final o2 = _orientation(x1, x2, y2);
  final o3 = _orientation(y1, y2, x1);
  final o4 = _orientation(y1, y2, x2);

  // General case: If orientation pairs are different, the line segments
  // intersect.
  if (o1 != o2 && o3 != o4) return true;

  // Special cases: Intersection when the line segments are collinear.
  if (o1 == 0 && _onSegment(x1, y1, x2)) return true;
  if (o2 == 0 && _onSegment(x1, y2, x2)) return true;
  if (o3 == 0 && _onSegment(y1, x1, y2)) return true;
  if (o4 == 0 && _onSegment(y1, x2, y2)) return true;

  // If none of the above cases hold, the line segments don't intersect.
  return false;
}

bool _pointInsideBox(Point p, Point minBox, Point maxBox) {
  return p.x >= minBox.x &&
      p.x <= maxBox.x &&
      p.y >= minBox.y &&
      p.y <= maxBox.y;
}

/// Checks if the line segment bounded by [x, y] intersects with the box
/// bounded by [minBox, maxBox].
bool lineIntersectsBox(Point p1, Point p2, Point minBox, Point maxBox) {
  // Define the corners of the box.
  Point topLeft = minBox;
  Point topRight = Point(maxBox.x, minBox.y);
  Point bottomLeft = Point(minBox.x, maxBox.y);
  Point bottomRight = maxBox;

  // Check if the line segment intersects any of the box edges.
  if (_intersects(p1, p2, topLeft, topRight)) return true;
  if (_intersects(p1, p2, topLeft, bottomLeft)) return true;
  if (_intersects(p1, p2, bottomLeft, bottomRight)) return true;
  if (_intersects(p1, p2, topRight, bottomRight)) return true;

  // Check if the line segment is entirely inside the box.
  if (_pointInsideBox(p1, minBox, maxBox) &&
      _pointInsideBox(p2, minBox, maxBox)) {
    return true;
  }

  // If none of the above cases hold, the line doesn't intersect the box.
  return false;
}

/// Checks if two axis-aligned boxes intersect.
bool boxesIntersect(
    Point minBox1, Point maxBox1, Point minBox2, Point maxBox2) {
  // Check if the boxes don't intersect by finding a separating axis.
  if (maxBox1.x < minBox2.x || minBox1.x > maxBox2.x) return false;
  if (maxBox1.y < minBox2.y || minBox1.y > maxBox2.y) return false;

  // If no separating axis was found, the boxes intersect.
  return true;
}
