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

#include "modules/processors/control_value_visualization.h"

#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_core/juce_core.h>

namespace anthem {

class ControlValueVisualizationProcessorTest : public juce::UnitTest {
public:
  ControlValueVisualizationProcessorTest()
    : juce::UnitTest("ControlValueVisualizationProcessorTest", "Anthem") {}

  void runTest() override {
    testProviderDrainsLatestValueOnly();
    testBlockValueUsesFinalSample();
  }

  void testProviderDrainsLatestValueOnly() {
    beginTest("Control value visualization provider drains latest value only");

    ControlValueVisualizationProvider provider;
    provider.rt_pushValue(0.1, 100);
    provider.rt_pushValue(0.4, 120);
    provider.rt_pushValue(0.8, 140);

    auto data = provider.getTypedData();

    expect(data.has_value(), "Buffered values should be returned");
    if (data.has_value()) {
      expectEquals(static_cast<int>(data->values.size()), 1, "Only the latest value is sent");
      expectEquals(
          static_cast<int>(data->sampleTimestamps.size()), 1, "Only one timestamp is sent");
      expectWithinAbsoluteError(data->values[0], 0.8, 0.0001, "Latest value");
      expectEquals(data->sampleTimestamps[0], static_cast<int64_t>(140), "Latest timestamp");
    }

    expect(!provider.getTypedData().has_value(), "Draining should empty the provider buffer");
  }

  void testBlockValueUsesFinalSample() {
    beginTest("Control value visualization reads the final block sample");

    juce::AudioSampleBuffer buffer(1, 4);
    buffer.setSample(0, 0, 0.1f);
    buffer.setSample(0, 1, 0.2f);
    buffer.setSample(0, 2, 0.3f);
    buffer.setSample(0, 3, 0.6f);

    auto value = ControlValueVisualizationProcessor::rt_getBlockValue(&buffer, 4, 50);

    expect(value.has_value(), "A non-empty control buffer should produce a value");
    if (value.has_value()) {
      expectWithinAbsoluteError(value->value, 0.6, 0.0001, "Final sample value");
      expectEquals(value->sampleTimestamp, static_cast<int64_t>(54), "Block-end timestamp");
    }

    buffer.setSample(0, 3, 1.3f);
    value = ControlValueVisualizationProcessor::rt_getBlockValue(&buffer, 4, 50);
    expect(value.has_value(), "Out-of-range values should still produce a clamped value");
    if (value.has_value()) {
      expectWithinAbsoluteError(value->value, 1.0, 0.0001, "Upper clamp");
    }

    buffer.setSample(0, 3, -0.3f);
    value = ControlValueVisualizationProcessor::rt_getBlockValue(&buffer, 4, 50);
    expect(value.has_value(), "Out-of-range values should still produce a clamped value");
    if (value.has_value()) {
      expectWithinAbsoluteError(value->value, 0.0, 0.0001, "Lower clamp");
    }

    expect(!ControlValueVisualizationProcessor::rt_getBlockValue(nullptr, 4, 50).has_value(),
        "Null buffers should not produce values");
    expect(!ControlValueVisualizationProcessor::rt_getBlockValue(&buffer, 0, 50).has_value(),
        "Empty blocks should not produce values");
  }
};

static ControlValueVisualizationProcessorTest controlValueVisualizationProcessorTest;

} // namespace anthem
