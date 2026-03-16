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

#include <juce_core/juce_core.h>

#include <optional>
#include <cstdint>
#include <memory>
#include <vector>

#include "modules/core/visualization/visualization_provider.h"
#include "modules/core/visualization/visualization_broker.h"

#include "modules/util/ring_buffer.h"

class CpuVisualizationProvider : public VisualizationDataProvider {
private:
  JUCE_LEAK_DETECTOR(CpuVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<double>, 2048> cpuBurdenBuffer;

public:
  std::optional<NumericVisualizationData> getNumericData() override;

  void rt_updateCpuBurden(double newCpuBurden, int64_t sampleTimestamp);

  CpuVisualizationProvider()
    : cpuBurdenBuffer(RingBuffer<TimestampedVisualizationValue<double>, 2048>()) {}
};

class PlayheadPositionVisualizationProvider : public VisualizationDataProvider {
private:
  JUCE_LEAK_DETECTOR(PlayheadPositionVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<double>, 2048> playheadPositionBuffer;

public:
  std::optional<NumericVisualizationData> getNumericData() override;

  void rt_updatePlayheadPosition(double newPlayheadPosition, int64_t sampleTimestamp);

  PlayheadPositionVisualizationProvider()
    : playheadPositionBuffer(RingBuffer<TimestampedVisualizationValue<double>, 2048>()) {}
};

class PlayheadSequenceIdVisualizationProvider : public VisualizationDataProvider {
private:
  JUCE_LEAK_DETECTOR(PlayheadSequenceIdVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<int64_t>, 64> playheadSequenceIdBuffer;
  std::optional<int64_t> lastQueuedId;

public:
  std::optional<IntegerVisualizationData> getIntegerData() override;

  void rt_updatePlayheadSequenceId(
    int64_t newPlayheadSequenceId,
    int64_t sampleTimestamp
  );

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
