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

#include "modules/render/render_tail_detector.h"

#include <juce_core/juce_core.h>

namespace anthem {

class RenderTailDetectorTest : public juce::UnitTest {
public:
  RenderTailDetectorTest() : juce::UnitTest("RenderTailDetectorTest", "Anthem") {}

  void runTest() override {
    testSecondsToSamplesRoundsUp();
    testRequiresSustainedSilenceAndResetsOnAudibleBlocks();
  }

  void testSecondsToSamplesRoundsUp() {
    beginTest("Tail detector sample conversion rounds up");

    expectEquals(RenderTailDetector::secondsToSamples(0.5, 3.0),
        static_cast<int64_t>(2),
        "Fractional sample counts should round up.");
  }

  void testRequiresSustainedSilenceAndResetsOnAudibleBlocks() {
    beginTest("Tail detector requires sustained silence and resets on audible blocks");

    auto detector = RenderTailDetector(4);
    auto buffer = juce::AudioSampleBuffer(2, 2);

    buffer.clear();
    expect(!detector.processBlock(buffer, 2, 2), "Two silent samples should not finish the tail.");
    expectEquals(detector.getConsecutiveSilentSamples(),
        static_cast<int64_t>(2),
        "The detector should count the first silent block.");

    buffer.clear();
    buffer.setSample(1, 0, -0.001f);
    expect(!detector.processBlock(buffer, 2, 2), "An audible block should not finish the tail.");
    expectEquals(detector.getConsecutiveSilentSamples(),
        static_cast<int64_t>(0),
        "The detector should reset after an audible block.");

    buffer.clear();
    expect(!detector.processBlock(buffer, 2, 2), "Silence must be sustained across blocks.");
    expect(detector.processBlock(buffer, 2, 2), "Four consecutive silent samples should finish.");
  }
};

static RenderTailDetectorTest renderTailDetectorTest;

} // namespace anthem
