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

import 'package:anthem_codegen/generators/util/writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Writer.nextIdentifier', () {
    test('uses a shared camelCase namespace prefix', () {
      final writer = Writer();

      expect(
        writer.nextIdentifier('fieldNameNullable'),
        'anthemCodegenFieldNameNullable0',
      );
      expect(writer.nextIdentifier('result'), 'anthemCodegenResult1');
    });

    test('rejects non-camel-case stems', () {
      final writer = Writer();

      expect(
        () => writer.nextIdentifier('field_name_nullable'),
        throwsArgumentError,
      );
    });

    test('keeps identifiers unique across calls', () {
      final writer = Writer();

      expect(writer.nextIdentifier('fieldName'), 'anthemCodegenFieldName0');
      expect(writer.nextIdentifier('fieldName'), 'anthemCodegenFieldName1');
    });
  });
}
