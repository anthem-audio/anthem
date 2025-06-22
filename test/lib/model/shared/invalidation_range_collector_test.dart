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

import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final collector = InvalidationRangeCollector(8);

  void validateRanges(List<(int, int)> expectedRanges) {
    expect(collector.size, expectedRanges.length);
    final actualRanges = collector.getRanges();
    for (var i = 0; i < expectedRanges.length; i++) {
      final range = expectedRanges[i];
      expect(range, equals((actualRanges[i].start, actualRanges[i].end)));
    }
  }

  setUp(() {
    collector.reset();
  });

  test('Initial state', () {
    final emptyCollector = InvalidationRangeCollector(8);
    expect(emptyCollector.size, 0);
    expect(emptyCollector.getRanges(), isEmpty);
  });

  test('Add single range', () {
    collector.addRange(10, 20);
    expect(collector.size, 1);
    validateRanges([(10, 20)]);
  });

  test('Add overlapping ranges (1)', () {
    collector.addRange(10, 20);
    collector.addRange(15, 25);
    expect(collector.size, 1);
    validateRanges([(10, 25)]);
  });

  test('Add overlapping ranges (2)', () {
    collector.addRange(10, 20);
    collector.addRange(5, 15);
    expect(collector.size, 1);
    validateRanges([(5, 20)]);
  });

  test('Add overlapping ranges (3)', () {
    collector.addRange(10, 20);
    collector.addRange(12, 18);
    expect(collector.size, 1);
    validateRanges([(10, 20)]);
  });

  test('Add overlapping ranges (3)', () {
    collector.addRange(10, 20);
    collector.addRange(8, 22);
    expect(collector.size, 1);
    validateRanges([(8, 22)]);
  });

  test('Add non-overlapping ranges', () {
    collector.addRange(10, 20);
    collector.addRange(30, 40);
    expect(collector.size, 2);
    validateRanges([(10, 20), (30, 40)]);
  });

  test('Add adjacent ranges (1)', () {
    collector.addRange(10, 20);
    collector.addRange(20, 30);
    expect(collector.size, 1);
    validateRanges([(10, 30)]);
  });

  test('Add adjacent ranges (2)', () {
    collector.addRange(10, 20);
    collector.addRange(5, 10);
    expect(collector.size, 1);
    validateRanges([(5, 20)]);
  });

  test('Add multiple ranges', () {
    collector.addRange(10, 20);
    collector.addRange(30, 40);
    collector.addRange(15, 35);
    collector.addRange(50, 60);
    collector.addRange(45, 55);
    expect(collector.size, 2);
    validateRanges([(10, 40), (45, 60)]);
  });

  test('Saturate collector', () {
    collector.addRange(0, 10);
    collector.addRange(20, 30);
    collector.addRange(40, 50);
    collector.addRange(60, 70);
    collector.addRange(80, 90);
    collector.addRange(100, 110);
    collector.addRange(120, 130);
    collector.addRange(140, 150);

    expect(collector.size, 8);
    validateRanges([
      (0, 10),
      (20, 30),
      (40, 50),
      (60, 70),
      (80, 90),
      (100, 110),
      (120, 130),
      (140, 150),
    ]);

    // Adding another range at the end should cause the first two to combine
    collector.addRange(160, 170);
    expect(collector.size, 8);
    validateRanges([
      (0, 30),
      (40, 50),
      (60, 70),
      (80, 90),
      (100, 110),
      (120, 130),
      (140, 150),
      (160, 170),
    ]);

    // If we add a range that is very close to an existing range, that is the one that will combine instead
    collector.addRange(98, 99);
    expect(collector.size, 8);
    validateRanges([
      (0, 30),
      (40, 50),
      (60, 70),
      (80, 90),
      (98, 110),
      (120, 130),
      (140, 150),
      (160, 170),
    ]);

    // If we add a range that covers multiple, it should combine properly
    collector.addRange(45, 155);
    expect(collector.size, 3);
    validateRanges([(0, 30), (40, 155), (160, 170)]);

    // If we add a range that is completely contained within an existing range,
    // nothing should change
    collector.addRange(50, 60);
    expect(collector.size, 3);
    validateRanges([(0, 30), (40, 155), (160, 170)]);

    collector.addRange(0, 180);
    expect(collector.size, 1);
    validateRanges([(0, 180)]);
  });
}
