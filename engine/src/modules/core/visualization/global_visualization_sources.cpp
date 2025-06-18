/*
  Copyright (C) 2025 Joshua Wade

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

std::optional<std::vector<std::string>> PlayheadSequenceIdVisualizationProvider::getStringData() {
  auto result = playheadSequenceIdBuffer.read();

  if (!result.has_value()) {
    return std::nullopt;
  }

  // Make a std::string from the array<unsigned char, 16>
  std::string sequenceId;
  sequenceId.reserve(16);
  for (const auto& byte : result.value()) {
   if (byte == 0) {
     break; // Stop at the first null byte
   }

   sequenceId += static_cast<char>(byte);
  }

  // If the sequence ID is the same as the last sent ID, return nothing
  if (sequenceId == lastSentId) {
    return std::nullopt;
  }

  lastSentId = sequenceId;

  std::vector<std::string> resultList{ sequenceId };

  return resultList;
}

void PlayheadSequenceIdVisualizationProvider::rt_updatePlayheadSequenceId(const std::string& newPlayheadSequenceId) {
  // Convert the string to a char array and write it to the ring buffer
  std::array<char, 16> sequenceIdArray = {};

  const auto bytesToCopy = newPlayheadSequenceId.size();

  if (bytesToCopy > sequenceIdArray.size()) {
    jassertfalse; // This should never happen, though it could if the project file is corrupted
    return;
  }

  std::copy_n(newPlayheadSequenceId.begin(),
    bytesToCopy,
    sequenceIdArray.begin());

  // Write the sequence ID to the ring buffer
  //
  // This should be copying to heap memory that is already allocated, in which case this
  // function is real-time safe.
  playheadSequenceIdBuffer.add(sequenceIdArray);
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
