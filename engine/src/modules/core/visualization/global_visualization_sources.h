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

// This header contains visualization data providers for global data sources,
// such as the transport location and current CPU burden.

#pragma once

#include <atomic>
#include <memory>
#include <vector>

#include "modules/core/visualization/visualization_provider.h"
#include "modules/core/visualization/visualization_broker.h"

#include "modules/util/ring_buffer.h"

class CpuVisualizationProvider : public VisualizationDataProvider {
private:
  std::atomic<double> cpuBurden;
  std::atomic<bool> overwriteNextUpdate;

public:
  std::optional<std::vector<double>> getNumericData() override;

  void rt_updateCpuBurden(double newCpuBurden);

  CpuVisualizationProvider() : cpuBurden(0.0), overwriteNextUpdate(false) {}
};

class PlayheadPositionVisualizationProvider : public VisualizationDataProvider {
private:
  std::atomic<double> playheadPosition;

public:
  std::optional<std::vector<double>> getNumericData() override;

  void rt_updatePlayheadPosition(double newPlayheadPosition);

  PlayheadPositionVisualizationProvider() : playheadPosition(0.0) {}
};

class PlayheadSequenceIdVisualizationProvider : public VisualizationDataProvider {
private:
  RingBuffer<std::array<char, 16>, 3> playheadSequenceIdBuffer;
  std::string lastSentId;

public:
  std::optional<std::vector<std::string>> getStringData() override;

  void rt_updatePlayheadSequenceId(const std::string& newPlayheadSequenceId);

  PlayheadSequenceIdVisualizationProvider() : playheadSequenceIdBuffer(RingBuffer<std::array<char, 16>, 3>()) {
    lastSentId = "";
  };
};

class GlobalVisualizationSources {
public:
  // Measures the processing time relative to the buffer size.
  std::shared_ptr<CpuVisualizationProvider> cpuBurdenProvider;

  // The playhead position in the transport.
  std::shared_ptr<PlayheadPositionVisualizationProvider> playheadPositionProvider;

  // The playhead sequence ID in the transport.
  std::shared_ptr<PlayheadSequenceIdVisualizationProvider> playheadSequenceIdProvider;

  GlobalVisualizationSources();
};
