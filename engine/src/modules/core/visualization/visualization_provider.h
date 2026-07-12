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

#include "messages/messages.h"
#include "modules/util/ring_buffer.h"

#include <atomic>
#include <cstdint>
#include <optional>
#include <string>
#include <type_traits>
#include <variant>
#include <vector>

namespace anthem {

template <typename T> struct TimestampedVisualizationData {
  std::vector<int64_t> sampleTimestamps;
  std::vector<T> values;
};

template <typename T> struct TimestampedVisualizationValue {
  int64_t sampleTimestamp;
  T value;
};

using NumericVisualizationData = TimestampedVisualizationData<double>;
using IntegerVisualizationData = TimestampedVisualizationData<int64_t>;
using StringVisualizationData = TimestampedVisualizationData<std::string>;
using VisualizationDataPayload =
    std::variant<NumericVisualizationData, IntegerVisualizationData, StringVisualizationData>;

template <typename T, std::size_t Size>
std::optional<TimestampedVisualizationData<T>> drainTimestampedVisualizationBuffer(
    RingBuffer<TimestampedVisualizationValue<T>, Size>& buffer) {
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

// For streams where only the newest value matters, keep a single overwriteable
// value instead of a queue. Streams that need per-sample history should use a
// RingBuffer and drainTimestampedVisualizationBuffer().
template <typename T> class LatestTimestampedVisualizationValue {
private:
  static_assert(std::is_trivially_copyable_v<T>);
  static_assert(std::atomic<T>::is_always_lock_free);

  std::atomic<uint64_t> sequence = 0;
  std::atomic<int64_t> sampleTimestamp = 0;
  std::atomic<T> value = {};
  uint64_t lastReadSequence = 0;
public:
  void rt_set(T newValue, int64_t newSampleTimestamp) {
    const auto writeSequence = sequence.load(std::memory_order_relaxed) + 1;

    sequence.store(writeSequence, std::memory_order_release);
    sampleTimestamp.store(newSampleTimestamp, std::memory_order_relaxed);
    value.store(newValue, std::memory_order_relaxed);
    sequence.store(writeSequence + 1, std::memory_order_release);
  }

  std::optional<TimestampedVisualizationData<T>> drainLatest() {
    for (int attempt = 0; attempt < 8; attempt++) {
      const auto beginSequence = sequence.load(std::memory_order_acquire);
      if (beginSequence == 0 || beginSequence == lastReadSequence) {
        return std::nullopt;
      }

      if ((beginSequence & 1) != 0) {
        continue;
      }

      const auto latestSampleTimestamp = sampleTimestamp.load(std::memory_order_relaxed);
      const auto latestValue = value.load(std::memory_order_relaxed);
      const auto endSequence = sequence.load(std::memory_order_acquire);
      if (beginSequence != endSequence || (endSequence & 1) != 0) {
        continue;
      }

      lastReadSequence = endSequence;

      TimestampedVisualizationData<T> data;
      data.sampleTimestamps.push_back(latestSampleTimestamp);
      data.values.push_back(latestValue);

      return data;
    }

    return std::nullopt;
  }
};

// This non-templated base class is required for runtime polymorphism. The
// VisualizationBroker stores heterogeneous providers (double, int, string,
// etc.) in a single container keyed by ID, so it needs one common interface
// that is not templated on the payload type.
class VisualizationDataProvider {
public:
  virtual ~VisualizationDataProvider() = default;

  virtual VisualizationValueType getValueType() const = 0;
  virtual std::optional<VisualizationDataPayload> getData() = 0;
};

// This templated helper exists only to reduce per-provider boilerplate. Notice
// that getValueType() is overridden and just returns the type from the
// template, which prevents the actual providers from having to do this.
template <typename T, VisualizationValueType Type>
class TypedVisualizationDataProvider : public VisualizationDataProvider {
public:
  VisualizationValueType getValueType() const override {
    return Type;
  }

  std::optional<VisualizationDataPayload> getData() override {
    auto data = this->getTypedData();
    if (!data.has_value()) {
      return std::nullopt;
    }

    return VisualizationDataPayload(std::move(data.value()));
  }

  virtual std::optional<TimestampedVisualizationData<T>> getTypedData() = 0;
};

} // namespace anthem
