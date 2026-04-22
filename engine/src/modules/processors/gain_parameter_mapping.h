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

#pragma once

#include "bw_math.h"

#include <cmath>
#include <limits>

// IMPORTANT:
//
// The functions in this file should produce the same results as those in
// lib/helpers/gain_parameter_mapping.dart, so any mapping changes here should
// be mirrored there.
//
// test/engine_integration_test.dart compares the engine and Dart
// implementations and validates that they are identical (besides floating point
// precision differences).

namespace anthem {

constexpr double kGainParameterLinearSectionCeilingDb = -180.0;
constexpr double kGainParameterCurveSectionCeilingDb = -36.0;
constexpr double kGainParameterDbCeiling = 12.0;

constexpr double kGainParameterLinearSectionCeilingNormalized = 0.01;
constexpr double kGainParameterCurveSectionCeilingNormalized = 0.25;

constexpr double kGainParameterCurveExponent = 9.0;
constexpr float kGainParameterZeroDbNormalized = 0.8125f;

inline float gainLinearToDb(float linearGain) {
  if (linearGain <= 0.0f) {
    return -std::numeric_limits<float>::infinity();
  }

  if (linearGain < std::numeric_limits<float>::min()) {
    return static_cast<float>(20.0 * std::log10(static_cast<double>(linearGain)));
  }

  return bw_lin2dBf(linearGain);
}

inline float gainDbToLinear(float db) {
  if (std::isinf(db) && db < 0.0f) {
    return 0.0f;
  }

  return bw_dB2linf(db);
}

inline float gainParameterValueToDb(float parameterValue) {
  const double rawValue = static_cast<double>(parameterValue);

  if (rawValue < kGainParameterLinearSectionCeilingNormalized) {
    return static_cast<float>(kGainParameterLinearSectionCeilingDb +
                              gainLinearToDb(static_cast<float>(
                                  rawValue / kGainParameterLinearSectionCeilingNormalized)));
  }

  if (rawValue < kGainParameterCurveSectionCeilingNormalized) {
    const double normalizedValue = (rawValue - kGainParameterLinearSectionCeilingNormalized) /
                                   (kGainParameterCurveSectionCeilingNormalized -
                                       kGainParameterLinearSectionCeilingNormalized);

    return static_cast<float>(
        kGainParameterLinearSectionCeilingDb +
        std::pow(normalizedValue, 1.0 / kGainParameterCurveExponent) *
            (kGainParameterCurveSectionCeilingDb - kGainParameterLinearSectionCeilingDb));
  }

  return static_cast<float>(64.0 * (rawValue - kGainParameterZeroDbNormalized));
}

inline float gainDbToParameterValue(float db) {
  if (db >= kGainParameterDbCeiling) {
    return 1.0f;
  }

  const double dbValue = static_cast<double>(db);

  if (dbValue < kGainParameterLinearSectionCeilingDb) {
    return static_cast<float>(
        gainDbToLinear(static_cast<float>(dbValue - kGainParameterLinearSectionCeilingDb)) *
        kGainParameterLinearSectionCeilingNormalized);
  }

  if (dbValue < kGainParameterCurveSectionCeilingDb) {
    const double normalizedDb =
        (dbValue - kGainParameterLinearSectionCeilingDb) /
        (kGainParameterCurveSectionCeilingDb - kGainParameterLinearSectionCeilingDb);

    return static_cast<float>(kGainParameterLinearSectionCeilingNormalized +
                              std::pow(normalizedDb, kGainParameterCurveExponent) *
                                  (kGainParameterCurveSectionCeilingNormalized -
                                      kGainParameterLinearSectionCeilingNormalized));
  }

  return static_cast<float>(kGainParameterZeroDbNormalized + (dbValue / 64.0));
}

inline float gainParameterValueToLinear(float parameterValue) {
  return gainDbToLinear(gainParameterValueToDb(parameterValue));
}

} // namespace anthem
