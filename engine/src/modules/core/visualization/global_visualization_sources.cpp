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

std::optional<std::vector<double>> CpuVisualizationProvider::getNumericData() {
  auto result = cpuBurden.load();

  overwriteNextUpdate.store(true);

  std::vector resultList { result };

  return resultList;
}

// Every time we read, we want the max value since the last time we read. When
// writing below, if overwriteNextUpdate is true, we will overwrite the value
// regardless of the value. Otherwise, we will only overwrite the value if the
// new value is greater than the current value.
void CpuVisualizationProvider::rt_updateCpuBurden(double newCpuBurden) {
  if (overwriteNextUpdate.load()) {
    overwriteNextUpdate.store(false);
    cpuBurden.store(newCpuBurden);
    return;
  } else {
    auto currentCpuBurden = cpuBurden.load();
    if (newCpuBurden > currentCpuBurden) {
      cpuBurden.store(newCpuBurden);
    }
  }
}

std::optional<std::vector<double>> PlayheadPositionVisualizationProvider::getNumericData() {
  auto result = playheadPosition.load();
  
  std::vector<double> resultList{ result };

  return resultList;
}

void PlayheadPositionVisualizationProvider::rt_updatePlayheadPosition(double newPlayheadPosition) {
  playheadPosition.store(newPlayheadPosition);
}

std::optional<std::vector<int64_t>> PlayheadSequenceIdVisualizationProvider::getIntegerData() {
  auto result = playheadSequenceIdBuffer.read();

  if (!result.has_value()) {
    return std::nullopt;
  }

  // If the sequence ID is the same as the last sent ID, return nothing
  if (lastSentId.has_value() && result.value() == lastSentId.value()) {
    return std::nullopt;
  }

  lastSentId = result.value();

  std::vector<int64_t> resultList{ result.value() };

  return resultList;
}

void PlayheadSequenceIdVisualizationProvider::rt_updatePlayheadSequenceId(int64_t newPlayheadSequenceId) {
  playheadSequenceIdBuffer.add(newPlayheadSequenceId);
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
