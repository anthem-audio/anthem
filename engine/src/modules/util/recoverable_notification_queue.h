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

#include "modules/util/ring_buffer.h"

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <type_traits>

namespace anthem {

// Multiple producers share one RingBuffer writer. A busy writer or full buffer
// requests recovery immediately; producers never wait or retry.
template <typename T, size_t Capacity> class RecoverableNotificationQueue {
  friend class RecoverableNotificationQueueTest;
  static_assert(Capacity > 1);
  static_assert(std::is_trivially_copyable_v<T>);
  static_assert(std::atomic<uint64_t>::is_always_lock_free);
  static_assert(std::atomic<bool>::is_always_lock_free);

  struct Record {
    uint64_t generation;
    T value;
  };
  RingBuffer<Record, Capacity> records;
  std::atomic_flag writer = ATOMIC_FLAG_INIT;
  std::atomic<uint64_t> generation{0};
  std::atomic<bool> recoveryRequested{false};
public:
  // Read before changing authoritative state. An update overlapping a recovery
  // snapshot must request another snapshot when it finishes.
  uint64_t currentGeneration() const noexcept {
    return generation.load(std::memory_order_acquire);
  }

  bool tryPush(uint64_t notificationGeneration, const T& value) noexcept {
    if (writer.test_and_set(std::memory_order_acquire)) {
      requestRecovery();
      return false;
    }
    const bool pushed = (notificationGeneration & 1) == 0 &&
                        generation.load(std::memory_order_acquire) == notificationGeneration &&
                        records.add({.generation = notificationGeneration, .value = value});
    if (!pushed || generation.load(std::memory_order_acquire) != notificationGeneration)
      requestRecovery();
    writer.clear(std::memory_order_release);
    return pushed;
  }

  void requestRecovery() noexcept {
    recoveryRequested.store(true, std::memory_order_release);
  }

  // Single-consumer operations. Recovery temporarily suppresses publication;
  // records from before the snapshot are discarded, including late producers.
  bool takeRecoveryRequest() noexcept {
    return recoveryRequested.exchange(false, std::memory_order_acq_rel);
  }
  void beginRecovery() noexcept {
    generation.fetch_add(1, std::memory_order_acq_rel);
  }
  void endRecovery() noexcept {
    generation.fetch_add(1, std::memory_order_release);
  }

  std::optional<T> tryPop() noexcept {
    for (size_t attempt = 0; attempt < Capacity; ++attempt) {
      const auto record = records.read();
      if (!record)
        return std::nullopt;
      if (record->generation == generation.load(std::memory_order_acquire))
        return record->value;
      // A producer may have finished its authoritative update after the last
      // recovery snapshot. Refresh once more after observing its publication.
      requestRecovery();
    }
    return std::nullopt;
  }
};

} // namespace anthem
