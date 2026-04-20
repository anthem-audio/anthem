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

#include "modules/sequencer/runtime/sequencer_timing.h"

#include <cmath>
#include <juce_core/juce_core.h>

namespace anthem {

class SequencerTimingTest : public juce::UnitTest {
  static bool nearlyEqual(double a, double b) {
    return std::abs(a - b) < 0.0001;
  }
public:
  SequencerTimingTest() : juce::UnitTest("SequencerTimingTest", "Anthem") {}

  void runTest() override {
    auto timingParams = sequencer_timing::TimingParams{
        .ticksPerQuarter = 96,
        .beatsPerMinute = 120.0,
        .sampleRate = 48000.0,
    };

    beginTest("Tick delta converts to the expected sample offset");

    expect(nearlyEqual(sequencer_timing::tickDeltaToSampleOffset(1.0, timingParams), 250.0),
        "One tick at 96 TPQ and 120 BPM should span 250 samples at 48 kHz.");

    expect(nearlyEqual(sequencer_timing::tickDeltaToSampleOffset(0.512, timingParams), 128.0),
        "A partial tick delta should round-trip to the matching fractional sample offset.");

    expect(nearlyEqual(sequencer_timing::tickDeltaToSampleOffset(-0.512, timingParams), -128.0),
        "Negative tick deltas should preserve sign when converted.");

    beginTest("Sample count converts to the expected tick delta");

    expect(nearlyEqual(sequencer_timing::sampleCountToTickDelta(250.0, timingParams), 1.0),
        "250 samples should equal one tick at 96 TPQ, 120 BPM, and 48 kHz.");

    beginTest("Tick and sample block advances stay reciprocal");

    auto ticksForBlock = sequencer_timing::sampleCountToTickDelta(256.0, timingParams);

    expect(
        nearlyEqual(sequencer_timing::tickDeltaToSampleOffset(ticksForBlock, timingParams), 256.0),
        "A block-sized tick advance should convert back to the original sample count.");

    beginTest("Invalid timing state returns zero deltas");

    expectEquals(sequencer_timing::tickDeltaToSampleOffset(1.0,
                     sequencer_timing::TimingParams{
                         .ticksPerQuarter = 96,
                         .beatsPerMinute = 120.0,
                         .sampleRate = 0.0,
                     }),
        0.0,
        "Zero sample rate should not produce a finite sample offset.");
    expectEquals(sequencer_timing::sampleCountToTickDelta(1.0,
                     sequencer_timing::TimingParams{
                         .ticksPerQuarter = 0,
                         .beatsPerMinute = 120.0,
                         .sampleRate = 48000.0,
                     }),
        0.0,
        "Zero TPQ should not produce a finite tick delta.");

    beginTest("Loop wrapping normalizes positions into the loop range");

    expect(nearlyEqual(sequencer_timing::wrapPlayheadToLoop(17.0, 10.0, 14.0), 13.0),
        "Positions after the loop end should wrap into the loop range.");
    expect(nearlyEqual(sequencer_timing::wrapPlayheadToLoop(9.0, 10.0, 14.0), 13.0),
        "Positions before the loop start should wrap into the loop range.");

    beginTest("Loop-aware playhead advance wraps at the loop end");

    expect(nearlyEqual(sequencer_timing::advancePlayheadByTickDelta(13.0, 2.0, 10.0, 14.0), 11.0),
        "Advancing past the loop end should continue from the loop start.");
    expect(nearlyEqual(sequencer_timing::advancePlayheadByTickDelta(
                           13.0, 2.0, 0.0, std::numeric_limits<double>::infinity()),
               15.0),
        "Without a finite loop range, the playhead should advance linearly.");
  }
};

static SequencerTimingTest sequencerTimingTest;

} // namespace anthem
