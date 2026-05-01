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

#include "modules/processors/db_meter.h"

#include <cmath>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_core/juce_core.h>
#include <vector>

namespace anthem {

class DbMeterAccumulatorTest : public juce::UnitTest {
  struct PublishedValue {
    size_t channelIndex = 0;
    double valueDb = 0.0;
    int64_t sampleTimestamp = 0;
  };

  static double expectedDb(float linearValue) {
    if (linearValue <= 0.0f) {
      return -600.0;
    }

    return static_cast<double>(bw_lin2dBf(linearValue));
  }

  void expectPublishedValue(const PublishedValue& value,
      size_t expectedChannelIndex,
      double expectedValueDb,
      int64_t expectedTimestamp,
      const juce::String& context) {
    expectEquals(static_cast<int>(value.channelIndex),
        static_cast<int>(expectedChannelIndex),
        context + " channel");
    expectWithinAbsoluteError(value.valueDb, expectedValueDb, 0.0001, context + " value");
    expectEquals(value.sampleTimestamp, expectedTimestamp, context + " timestamp");
  }
public:
  DbMeterAccumulatorTest() : juce::UnitTest("DbMeterAccumulatorTest", "Anthem") {}

  void runTest() override {
    testPeakAccumulationPublishesPerWindow();
    testPeakAccumulationCarriesAcrossBlocks();
    testPublishIntervalClampsToOne();
    testPrepareResetsAccumulatedState();
    testVisualizationProviderDrainsBufferedValues();
  }

  void testPeakAccumulationPublishesPerWindow() {
    beginTest("Db meter accumulator publishes per-window channel peaks with timestamps");

    DbMeterAccumulator accumulator;
    accumulator.rt_prepare(2);

    juce::AudioBuffer<float> buffer(2, 4);
    buffer.setSample(0, 0, 0.25f);
    buffer.setSample(0, 1, -0.75f);
    buffer.setSample(0, 2, 0.10f);
    buffer.setSample(0, 3, 0.50f);
    buffer.setSample(1, 0, -0.50f);
    buffer.setSample(1, 1, 0.25f);
    buffer.setSample(1, 2, -1.00f);
    buffer.setSample(1, 3, 0.20f);

    std::vector<PublishedValue> published;
    accumulator.rt_processBlock(
        buffer, 4, 100, 2, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(static_cast<int>(published.size()), 4, "Two windows across two channels");
    expectPublishedValue(published[0], 0, expectedDb(0.75f), 102, "Window one left");
    expectPublishedValue(published[1], 1, expectedDb(0.50f), 102, "Window one right");
    expectPublishedValue(published[2], 0, expectedDb(0.50f), 104, "Window two left");
    expectPublishedValue(published[3], 1, expectedDb(1.00f), 104, "Window two right");
  }

  void testPeakAccumulationCarriesAcrossBlocks() {
    beginTest("Db meter accumulator carries the peak across blocks until the publish boundary");

    DbMeterAccumulator accumulator;
    accumulator.rt_prepare(1);

    juce::AudioBuffer<float> firstBlock(1, 1);
    firstBlock.setSample(0, 0, 0.70f);

    std::vector<PublishedValue> published;
    accumulator.rt_processBlock(
        firstBlock, 1, 10, 3, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(static_cast<int>(published.size()), 0, "The first block should not publish yet");

    juce::AudioBuffer<float> secondBlock(1, 2);
    secondBlock.setSample(0, 0, 0.20f);
    secondBlock.setSample(0, 1, 0.30f);

    accumulator.rt_processBlock(
        secondBlock, 2, 11, 3, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(
        static_cast<int>(published.size()), 1, "The second block should complete a window");
    expectPublishedValue(published[0], 0, expectedDb(0.70f), 13, "Cross-block peak");
  }

  void testPublishIntervalClampsToOne() {
    beginTest("Db meter accumulator clamps publish intervals below one sample");

    DbMeterAccumulator accumulator;
    accumulator.rt_prepare(1);

    juce::AudioBuffer<float> buffer(1, 2);
    buffer.setSample(0, 0, 0.0f);
    buffer.setSample(0, 1, 0.5f);

    std::vector<PublishedValue> published;
    accumulator.rt_processBlock(
        buffer, 2, 40, 0, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(
        static_cast<int>(published.size()), 2, "A clamped interval should emit per sample");
    expectPublishedValue(published[0], 0, -600.0, 41, "Silent sample");
    expectPublishedValue(published[1], 0, expectedDb(0.50f), 42, "Second sample");
  }

  void testPrepareResetsAccumulatedState() {
    beginTest("Db meter accumulator prepare resets pending peaks and counters");

    DbMeterAccumulator accumulator;
    accumulator.rt_prepare(1);

    juce::AudioBuffer<float> firstBlock(1, 1);
    firstBlock.setSample(0, 0, 1.0f);

    std::vector<PublishedValue> published;
    accumulator.rt_processBlock(
        firstBlock, 1, 0, 3, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(static_cast<int>(published.size()), 0, "A partial window should stay buffered");

    accumulator.rt_prepare(1);

    juce::AudioBuffer<float> secondBlock(1, 1);
    secondBlock.setSample(0, 0, 0.25f);

    accumulator.rt_processBlock(
        secondBlock, 1, 20, 1, [&](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
          published.push_back(PublishedValue{
              .channelIndex = channelIndex,
              .valueDb = valueDb,
              .sampleTimestamp = sampleTimestamp,
          });
        });

    expectEquals(static_cast<int>(published.size()), 1, "Prepare should clear the partial window");
    expectPublishedValue(published[0], 0, expectedDb(0.25f), 21, "Post-prepare value");
  }

  void testVisualizationProviderDrainsBufferedValues() {
    beginTest("Db meter visualization provider drains buffered values");

    DbMeterVisualizationProvider provider;
    provider.rt_pushValue(-12.0, 100);
    provider.rt_pushValue(-3.0, 120);

    auto data = provider.getTypedData();

    expect(data.has_value(), "Buffered values should be returned");
    if (data.has_value()) {
      expectEquals(static_cast<int>(data->values.size()), 2, "Two values should be drained");
      expectEquals(
          static_cast<int>(data->sampleTimestamps.size()), 2, "Two timestamps should be drained");
      expectWithinAbsoluteError(data->values[0], -12.0, 0.0001, "First value");
      expectWithinAbsoluteError(data->values[1], -3.0, 0.0001, "Second value");
      expectEquals(data->sampleTimestamps[0], static_cast<int64_t>(100), "First timestamp");
      expectEquals(data->sampleTimestamps[1], static_cast<int64_t>(120), "Second timestamp");
    }

    expect(!provider.getTypedData().has_value(), "Draining should empty the provider buffer");
  }
};

static DbMeterAccumulatorTest dbMeterAccumulatorTest;

} // namespace anthem
