/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

// This header contains visualization data providers for global data sources,
// such as the transport location and current CPU burden.

#pragma once

#include "modules/core/visualization/visualization_broker.h"
#include "modules/core/visualization/visualization_provider.h"
#include "modules/util/ring_buffer.h"

#include <cstdint>
#include <juce_core/juce_core.h>
#include <memory>
#include <optional>
#include <vector>

class Transport;

class CpuVisualizationProvider
  : public TypedVisualizationDataProvider<double, VisualizationValueType::doubleValue> {
private:
  JUCE_LEAK_DETECTOR(CpuVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<double>, 2048> cpuBurdenBuffer;
  double rt_sampleRate = 0.0;
  int64_t rt_samplesPerWindow = 0;
  int64_t rt_nextWindowEndSample = 0;
  double rt_windowMaxCpuBurden = 0.0;
  bool rt_hasWindowCpuBurden = false;
public:
  std::optional<NumericVisualizationData> getTypedData() override;

  void rt_updateCpuBurden(double newCpuBurden,
                          int64_t blockStartSample,
                          int numSamples,
                          double sampleRate);

  CpuVisualizationProvider()
    : cpuBurdenBuffer(RingBuffer<TimestampedVisualizationValue<double>, 2048>()) {}
};

class PlayheadPositionVisualizationProvider
  : public TypedVisualizationDataProvider<double, VisualizationValueType::doubleValue> {
private:
  JUCE_LEAK_DETECTOR(PlayheadPositionVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<double>, 2048> playheadPositionBuffer;
  double rt_sampleRate = 0.0;
  int64_t rt_samplesPerUpdate = 0;
  int64_t rt_nextSampleTimestamp = 0;
public:
  std::optional<NumericVisualizationData> getTypedData() override;

  void rt_updatePlayheadPosition(const Transport& transport,
                                 int64_t blockStartSample,
                                 int numSamples,
                                 double sampleRate);

  PlayheadPositionVisualizationProvider()
    : playheadPositionBuffer(RingBuffer<TimestampedVisualizationValue<double>, 2048>()) {}
};

class PlayheadSequenceIdVisualizationProvider
  : public TypedVisualizationDataProvider<int64_t, VisualizationValueType::intValue> {
private:
  JUCE_LEAK_DETECTOR(PlayheadSequenceIdVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<int64_t>, 64> playheadSequenceIdBuffer;
  std::optional<int64_t> lastQueuedId;
public:
  std::optional<IntegerVisualizationData> getTypedData() override;

  void rt_updatePlayheadSequenceId(int64_t newPlayheadSequenceId, int64_t sampleTimestamp);

  PlayheadSequenceIdVisualizationProvider()
    : playheadSequenceIdBuffer(RingBuffer<TimestampedVisualizationValue<int64_t>, 64>()) {}
};

class GlobalVisualizationSources {
private:
  JUCE_LEAK_DETECTOR(GlobalVisualizationSources)
public:
  // Measures the processing time relative to the buffer size.
  std::shared_ptr<CpuVisualizationProvider> cpuBurdenProvider;

  // The playhead position in the transport.
  std::shared_ptr<PlayheadPositionVisualizationProvider> playheadPositionProvider;

  // The playhead sequence ID in the transport.
  std::shared_ptr<PlayheadSequenceIdVisualizationProvider> playheadSequenceIdProvider;

  GlobalVisualizationSources();
};
