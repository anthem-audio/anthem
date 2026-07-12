/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasAnnotationSet', () {
    test('hitTest returns topmost annotation and local offset', () {
      final annotations = CanvasAnnotationSet<int>()
        ..add(rect: const Rect.fromLTWH(0, 0, 20, 20), metadata: 1)
        ..add(rect: const Rect.fromLTWH(10, 12, 40, 30), metadata: 2);

      final hit = annotations.hitTest(const Offset(18, 27));

      expect(hit, isNotNull);
      expect(hit!.annotation.metadata, 2);
      expect(hit.annotation.rect, const Rect.fromLTWH(10, 12, 40, 30));
      expect(hit.offset, const Offset(8, 15));
    });

    test('hitTest returns null when no annotation contains the point', () {
      final annotations = CanvasAnnotationSet<int>()
        ..add(rect: const Rect.fromLTWH(0, 0, 20, 20), metadata: 1)
        ..add(rect: const Rect.fromLTWH(10, 12, 40, 30), metadata: 2);

      expect(annotations.hitTest(const Offset(60, 60)), isNull);
    });
  });
}
