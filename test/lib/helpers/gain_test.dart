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

import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gainParameterValueToDb', () {
    test('maps the key curve breakpoints', () {
      expect(gainParameterValueToDb(0.0), double.negativeInfinity);
      expect(
        gainParameterValueToDb(gainParameterLinearSectionCeilingNormalized),
        closeTo(gainParameterLinearSectionCeilingDb, 1e-9),
      );
      expect(
        gainParameterValueToDb(gainParameterCurveSectionCeilingNormalized),
        closeTo(gainParameterCurveSectionCeilingDb, 1e-9),
      );
      expect(
        gainParameterValueToDb(1.0),
        closeTo(gainParameterDbCeiling, 1e-9),
      );
      expect(
        gainParameterValueToDb(gainParameterZeroDbNormalized),
        closeTo(0.0, 1e-9),
      );
    });

    test('maps unity gain to exactly 0 dB', () {
      expect(gainParameterValueToDb(gainParameterZeroDbNormalized), 0.0);
    });
  });

  group('gainDbToParameterValue', () {
    test('maps the key curve breakpoints', () {
      expect(gainDbToParameterValue(double.negativeInfinity), 0.0);
      expect(
        gainDbToParameterValue(gainParameterLinearSectionCeilingDb),
        closeTo(gainParameterLinearSectionCeilingNormalized, 1e-9),
      );
      expect(
        gainDbToParameterValue(gainParameterCurveSectionCeilingDb),
        closeTo(gainParameterCurveSectionCeilingNormalized, 1e-9),
      );
      expect(
        gainDbToParameterValue(gainParameterDbCeiling),
        closeTo(1.0, 1e-9),
      );
      expect(
        gainDbToParameterValue(0.0),
        closeTo(gainParameterZeroDbNormalized, 1e-9),
      );
    });

    test('clamps values above +12 dB to the top of the range', () {
      expect(gainDbToParameterValue(18.0), 1.0);
    });

    test('round-trips the shared gain curve', () {
      const samples = <double>[
        0.0,
        0.01,
        0.01001,
        0.02,
        0.25,
        0.5,
        0.75,
        gainParameterZeroDbNormalized,
        1.0,
      ];

      for (final sample in samples) {
        final db = gainParameterValueToDb(sample);
        final roundTripped = gainDbToParameterValue(db);
        expect(roundTripped, closeTo(sample, 1e-9));
      }
    });
  });

  group('formatDb', () {
    test('formats negative infinity with unicode infinity and units', () {
      expect(formatDb(double.negativeInfinity), '-\u221e');
      expect(
        formatDb(double.negativeInfinity, includeUnit: true),
        '-\u221e dB',
      );
    });

    test('formats whole and fractional values', () {
      expect(formatDb(12.0), '+12');
      expect(formatDb(1.5), '+1.5');
      expect(formatDb(-4.0), '-4');
      expect(formatDb(0.0), '0');
      expect(gainParameterValueToString(gainParameterZeroDbNormalized), '0 dB');
    });
  });
}
