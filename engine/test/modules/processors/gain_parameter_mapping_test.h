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

#include "modules/processors/gain_parameter_mapping.h"

#include <array>
#include <cmath>
#include <juce_core/juce_core.h>

class GainParameterMappingTest : public juce::UnitTest {
public:
  GainParameterMappingTest() : juce::UnitTest("GainParameterMappingTest", "Anthem") {}

  void runTest() override {
    constexpr float comparisonToleranceDb = 0.0003f;

    beginTest("Gain parameter mapping hits the expected breakpoint values");

    expect(std::isinf(gainParameterValueToDb(0.0f)));
    expect(
        std::abs(gainParameterValueToDb(
                     static_cast<float>(kGainParameterLinearSectionCeilingNormalized)) -
                 static_cast<float>(kGainParameterLinearSectionCeilingDb)) < comparisonToleranceDb,
        "the linear section ceiling should map to -180 dB");
    expect(
        std::abs(gainParameterValueToDb(
                     static_cast<float>(kGainParameterCurveSectionCeilingNormalized)) -
                 static_cast<float>(kGainParameterCurveSectionCeilingDb)) < comparisonToleranceDb,
        "the curve section ceiling should map to -36 dB");
    expect(std::abs(gainParameterValueToDb(kGainParameterZeroDbNormalized) - 0.0f) <
               comparisonToleranceDb,
        "unity gain should map to 0 dB");
    expect(std::abs(gainParameterValueToDb(1.0f) - static_cast<float>(kGainParameterDbCeiling)) <
               comparisonToleranceDb,
        "the top of the parameter range should map to +12 dB");

    beginTest("Gain parameter mapping clamps values above +12 dB");

    expect(gainDbToParameterValue(18.0f) == 1.0f,
        "values above +12 dB should clamp to the top of the range");

    beginTest("Gain parameter mapping maps unity gain to exactly 0 dB");

    expect(gainParameterValueToDb(kGainParameterZeroDbNormalized) == 0.0f,
        "unity gain should map to an exact 0 dB value");

    beginTest("Gain parameter mapping round-trips breakpoint and unity values");

    const auto roundTripSamples = std::array<float, 9>{
        0.0f,
        0.01f,
        0.01001f,
        0.02f,
        0.25f,
        0.5f,
        0.75f,
        kGainParameterZeroDbNormalized,
        1.0f,
    };

    for (const auto sample : roundTripSamples) {
      const auto db = gainParameterValueToDb(sample);

      if (std::isinf(db) && db < 0.0f) {
        expect(gainDbToParameterValue(db) == 0.0f);
      } else {
        expect(std::abs(gainDbToParameterValue(db) - sample) < 0.000001f,
            "the shared gain mapping should round-trip representative samples");
      }
    }

    beginTest("Gain parameter mapping converts to linear gain consistently");

    expect(std::abs(gainParameterValueToLinear(
                        static_cast<float>(kGainParameterLinearSectionCeilingNormalized)) -
                    gainDbToLinear(static_cast<float>(kGainParameterLinearSectionCeilingDb))) <
               comparisonToleranceDb,
        "the curve breakpoint should match the dB floor in linear space");
    expect(std::abs(gainParameterValueToLinear(1.0f) -
                    gainDbToLinear(static_cast<float>(kGainParameterDbCeiling))) <
               comparisonToleranceDb,
        "the top of the range should match +12 dB in linear space");
  }
};

static GainParameterMappingTest gainParameterMappingTest;
