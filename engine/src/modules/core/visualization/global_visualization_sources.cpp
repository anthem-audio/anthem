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

#include "global_visualization_sources.h"

std::optional<NumericVisualizationData> CpuVisualizationProvider::getNumericData() {
  return drainTimestampedVisualizationBuffer(cpuBurdenBuffer);
}

void CpuVisualizationProvider::rt_updateCpuBurden(
  double newCpuBurden,
  int64_t sampleTimestamp
) {
  cpuBurdenBuffer.add(
    TimestampedVisualizationValue<double>{
      .sampleTimestamp = sampleTimestamp,
      .value = newCpuBurden,
    }
  );
}

std::optional<NumericVisualizationData> PlayheadPositionVisualizationProvider::getNumericData() {
  return drainTimestampedVisualizationBuffer(playheadPositionBuffer);
}

void PlayheadPositionVisualizationProvider::rt_updatePlayheadPosition(
  double newPlayheadPosition,
  int64_t sampleTimestamp
) {
  playheadPositionBuffer.add(
    TimestampedVisualizationValue<double>{
      .sampleTimestamp = sampleTimestamp,
      .value = newPlayheadPosition,
    }
  );
}

std::optional<IntegerVisualizationData> PlayheadSequenceIdVisualizationProvider::getIntegerData() {
  return drainTimestampedVisualizationBuffer(playheadSequenceIdBuffer);
}

void PlayheadSequenceIdVisualizationProvider::rt_updatePlayheadSequenceId(
  int64_t newPlayheadSequenceId,
  int64_t sampleTimestamp
) {
  if (lastQueuedId.has_value() && lastQueuedId.value() == newPlayheadSequenceId) {
    return;
  }

  lastQueuedId = newPlayheadSequenceId;
  playheadSequenceIdBuffer.add(
    TimestampedVisualizationValue<int64_t>{
      .sampleTimestamp = sampleTimestamp,
      .value = newPlayheadSequenceId,
    }
  );
}

GlobalVisualizationSources::GlobalVisualizationSources() {
  cpuBurdenProvider = std::make_shared<CpuVisualizationProvider>();
  playheadPositionProvider = std::make_shared<PlayheadPositionVisualizationProvider>();
  playheadSequenceIdProvider = std::make_shared<PlayheadSequenceIdVisualizationProvider>();

  // Register global sources with the visualization broker
  VisualizationBroker::getInstance().registerDataProvider("cpu", cpuBurdenProvider);
  VisualizationBroker::getInstance().registerDataProvider("playhead_position", playheadPositionProvider);
  VisualizationBroker::getInstance().registerDataProvider("playhead_sequence_id", playheadSequenceIdProvider);
}
