/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/widgets/editors/arranger/rendering/clip_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clip paint bounds overshoot row content by one pixel per edge', () {
    final bounds = clipPaintVerticalBoundsForRow(rowTop: 10, rowHeight: 60);

    expect(bounds.top, 9);
    expect(bounds.bottom, 71);
  });

  test('automation content bounds include the clip paint overshoot', () {
    final bounds = automationContentVerticalBoundsForRow(
      rowTop: 10,
      rowHeight: 60,
    );

    expect(bounds.top, 27);
    expect(bounds.bottom, 69);
  });
}
