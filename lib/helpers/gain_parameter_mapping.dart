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

import 'dart:math' as math;

import 'package:anthem/helpers/bw_fast_math.dart';

// IMPORTANT:
//
// The functions in this file should produce the same results as those in
// engine/src/modules/processors/gain_parameter_mapping.h, so any mapping
// changes here should be mirrored there.
//
// test/engine_integration_test.dart compares the engine and Dart
// implementations and validates that they are identical (besides floating point
// precision differences).

// Overview:
//
// This file contains functions to map between a normalized (0 - 1) parameter
// value for gain, and db.
//
// A 1:1 linear mapping does not work in dBFS space, since 0 maps to -inf dBFS
// and 1 maps to +12 dBFS. This file contains a more complex mapping that has a
// few goals:
//
// 1. A parameter value of 0 should precisely map to -inf, not -(extremely
//    small), to allow for true silence.
// 2. The mapping must be continuous. Going from 0.0 to 0.00001 should not
//    produce a sudden (though very slight) jump in absolute gain. This
//    necessitates a very small region near the bottom that maps to absolute
//    gain instead of dBFS.
// 3. The mapping should squeeze more dBFS values near the bottom of the range,
//    since this is desirable from a usability standpoint
// 4. The mapping should be able to exactly represent 0.0 dBFS. There are tests
//    for this, and the normalized value that maps to 0.0 dBFS is stored in
//    gainParameterZeroDbNormalized.
// 5. The mapping must be bi-directional - we must have functions to go form
//    normalized values to dBFS, and from dBFS to normalized values. To this
//    end, the mapping used must be easily reversible.
//
// To enable these goals, the mapping is split into three ranges:
// 1. The first range is a very tiny range near the bottom that maps from -inf
//    to -180, by first converting to absolute gain.
// 2. The second range uses an exponential curve, calculated using bw_fast_math,
//    that ramps dBFS values so there are more near the bottom of the range than
//    the top.
// 3. The third range maps to pure dBFS, and takes up most of the normalized
//    range.

const gainParameterLinearSectionCeilingDb = -180.0;
const gainParameterCurveSectionCeilingDb = -36.0;
const gainParameterDbCeiling = 12.0;

const gainParameterLinearSectionCeilingNormalized = 0.01;
const gainParameterCurveSectionCeilingNormalized = 0.25;

const gainParameterCurveExponent = 9.0;
const gainParameterZeroDbNormalized = 0.8125;

const _gainFastLinearToDbMinNormal = 2.2250738585072014e-308;

double linearToDb(double linear) {
  if (linear <= 0.0) {
    return double.negativeInfinity;
  }

  if (linear < _gainFastLinearToDbMinNormal) {
    return 20 * math.log(linear) / math.ln10;
  }

  return bwLinearToDb(linear);
}

double dbToLinear(double db) {
  if (db.isInfinite && db.isNegative) {
    return 0.0;
  }

  return bwDbToLinear(db);
}

double gainParameterValueToDb(double rawValue) {
  if (rawValue < gainParameterLinearSectionCeilingNormalized) {
    return gainParameterLinearSectionCeilingDb +
        linearToDb(rawValue / gainParameterLinearSectionCeilingNormalized);
  }

  if (rawValue < gainParameterCurveSectionCeilingNormalized) {
    final normalizedValue =
        (rawValue - gainParameterLinearSectionCeilingNormalized) /
        (gainParameterCurveSectionCeilingNormalized -
            gainParameterLinearSectionCeilingNormalized);

    return gainParameterLinearSectionCeilingDb +
        math.pow(normalizedValue, 1.0 / gainParameterCurveExponent).toDouble() *
            (gainParameterCurveSectionCeilingDb -
                gainParameterLinearSectionCeilingDb);
  }

  return 64.0 * (rawValue - gainParameterZeroDbNormalized);
}

double gainDbToParameterValue(double db) {
  if (db >= gainParameterDbCeiling) {
    return 1.0;
  }

  if (db < gainParameterLinearSectionCeilingDb) {
    return dbToLinear(db - gainParameterLinearSectionCeilingDb) *
        gainParameterLinearSectionCeilingNormalized;
  }

  if (db < gainParameterCurveSectionCeilingDb) {
    final normalizedDb =
        (db - gainParameterLinearSectionCeilingDb) /
        (gainParameterCurveSectionCeilingDb -
            gainParameterLinearSectionCeilingDb);

    return gainParameterLinearSectionCeilingNormalized +
        math.pow(normalizedDb, gainParameterCurveExponent).toDouble() *
            (gainParameterCurveSectionCeilingNormalized -
                gainParameterLinearSectionCeilingNormalized);
  }

  return gainParameterZeroDbNormalized + (db / 64.0);
}

String formatDb(double db, {bool includeUnit = false}) {
  final value = switch ((db.isInfinite, db.isNegative)) {
    (true, true) => '-\u221e',
    _ when db == db.roundToDouble() => _formatSignedDbNumber(
      db.toInt().toString(),
      db,
    ),
    _ => _formatSignedDbNumber(db.toStringAsFixed(1), db),
  };

  return includeUnit ? '$value dB' : value;
}

String _formatSignedDbNumber(String formattedMagnitude, double db) {
  if (db > 0.0) {
    return '+$formattedMagnitude';
  }

  return formattedMagnitude;
}

String gainParameterValueToString(double rawValue) {
  return formatDb(gainParameterValueToDb(rawValue), includeUnit: true);
}
