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

#pragma once

#include <vector>
#include <optional>
#include <string>
#include <cstdint>

#include "modules/util/ring_buffer.h"

template <typename T>
struct TimestampedVisualizationData {
  std::vector<int64_t> sampleTimestamps;
  std::vector<T> values;
};

template <typename T>
struct TimestampedVisualizationValue {
  int64_t sampleTimestamp;
  T value;
};

using NumericVisualizationData = TimestampedVisualizationData<double>;
using IntegerVisualizationData = TimestampedVisualizationData<int64_t>;
using StringVisualizationData = TimestampedVisualizationData<std::string>;

template <typename T, std::size_t Size>
std::optional<TimestampedVisualizationData<T>> drainTimestampedVisualizationBuffer(
  RingBuffer<TimestampedVisualizationValue<T>, Size>& buffer
) {
  TimestampedVisualizationData<T> data;

  while (true) {
    auto item = buffer.read();
    if (!item.has_value()) {
      break;
    }

    data.sampleTimestamps.push_back(item->sampleTimestamp);
    data.values.push_back(item->value);
  }

  if (data.values.empty()) {
    return std::nullopt;
  }

  return data;
}

// This is an abstract interface for visualization data providers. It is used by the
// VisualizationBroker to query data from various sources in the engine.
class VisualizationDataProvider {
public:
  virtual ~VisualizationDataProvider() = default;

  // Get timestamped numeric data for this provider, if any.
  virtual std::optional<NumericVisualizationData> getNumericData() {
    return std::nullopt;
  }

  // Get timestamped integer data for this provider, if any.
  virtual std::optional<IntegerVisualizationData> getIntegerData() {
    return std::nullopt;
  }

  // Get timestamped string data for this provider, if any.
  virtual std::optional<StringVisualizationData> getStringData() {
    return std::nullopt;
  }
};
