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

#include "modules/core/visualization/global_visualization_sources.h"

#include <juce_core/juce_core.h>

namespace anthem {

class GlobalVisualizationSourcesTest : public juce::UnitTest {
public:
  GlobalVisualizationSourcesTest() : juce::UnitTest("GlobalVisualizationSourcesTest", "Anthem") {}

  void runTest() override {
    beginTest("An unchanged sequence ID refreshes timestamps across audio sessions");
    PlayheadSequenceIdVisualizationProvider provider;
    expect(!provider.getTypedData().has_value());

    provider.rt_updatePlayheadSequenceId(42, 48000);
    expectSnapshot(provider, 42, 48000);
    provider.rt_updatePlayheadSequenceId(42, 96000);
    expectSnapshot(provider, 42, 96000);

    // Audio reconfiguration resets the sample clock without changing the ID.
    provider.rt_updatePlayheadSequenceId(42, 0);
    expectSnapshot(provider, 42, 0);
    expect(
        !provider.getTypedData().has_value(), "No update is emitted without another audio block.");

    beginTest("Delayed polling publishes only the current sequence ID and timestamp");
    provider.rt_updatePlayheadSequenceId(42, 0);
    for (int64_t block = 1; block <= 100; ++block) {
      provider.rt_updatePlayheadSequenceId(42, block * 512);
    }
    provider.rt_updatePlayheadSequenceId(43, 101 * 512);
    expectSnapshot(provider, 43, 101 * 512);
  }
private:
  void expectSnapshot(
      PlayheadSequenceIdVisualizationProvider& provider, int64_t id, int64_t sampleTimestamp) {
    const auto data = provider.getTypedData();
    expect(data.has_value(), "Current state must be available even when the ID is unchanged.");
    if (!data.has_value()) {
      return;
    }
    expectEquals(data->values.size(), std::size_t{1});
    expectEquals(data->sampleTimestamps.size(), std::size_t{1});
    if (data->values.size() == 1 && data->sampleTimestamps.size() == 1) {
      expectEquals(data->values.front(), id);
      expectEquals(data->sampleTimestamps.front(), sampleTimestamp);
    }
  }
};

static GlobalVisualizationSourcesTest globalVisualizationSourcesTest;

} // namespace anthem
