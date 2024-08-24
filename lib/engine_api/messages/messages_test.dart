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

import 'messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test message serialization features', () {
    test('Serialization: basic values', () {
      for (var i = 0; i < 100; i++) {
        final random = Random();

        final id = random.nextInt(1000);
        final defaultValue = random.nextDouble();
        final maxValue = random.nextDouble();
        final minValue = random.nextDouble();

        final test = ProcessorParameterDescription.create(
          id: id,
          defaultValue: defaultValue,
          maxValue: maxValue,
          minValue: minValue,
        );

        final json = test.toJson_ANTHEM();

        expect(json['id'], id);
        expect(json['defaultValue'], defaultValue);
        expect(json['maxValue'], maxValue);
        expect(json['minValue'], minValue);

        expect(json.keys.length, 4);
      }
    });
  });
}
