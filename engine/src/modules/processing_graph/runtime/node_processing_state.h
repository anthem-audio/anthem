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

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <utility>

namespace anthem {

class GraphProcessor;
class NodeProcessingPause;

// The entry gate and the pause request share one atomic: either processing
// enters first and pause waits for its exit, or pause prevents that entry.
class NodeProcessingState {
  friend class NodeProcessingPause;
  static_assert(std::atomic<uint32_t>::is_always_lock_free);

  static constexpr uint32_t pauseRequested = 1;
  static constexpr uint32_t processing = 2;
  static constexpr uint32_t removed = 4;
  std::atomic<uint32_t> flags{0};
  // Pause ownership is changed only on the message thread.
  size_t pauseCount = 0;

  void requestPause() noexcept {
    ++pauseCount;
    flags.fetch_or(pauseRequested, std::memory_order_acq_rel);
  }
  void releasePause() noexcept {
    if (--pauseCount == 0)
      flags.fetch_and(~pauseRequested, std::memory_order_acq_rel);
  }
  void retire() noexcept {
    flags.fetch_or(removed, std::memory_order_acq_rel);
  }
public:
  enum class Phase { running, pauseRequested, paused, removed };

  Phase phase() const noexcept {
    const auto value = flags.load(std::memory_order_acquire);
    if ((value & removed) != 0)
      return Phase::removed;
    if ((value & pauseRequested) == 0)
      return Phase::running;
    return (value & processing) != 0 ? Phase::pauseRequested : Phase::paused;
  }

  // Checks availability and reserves access in one atomic attempt, without
  // waiting. Successful acquisition must be paired with release below.
  bool rt_tryAcquireProcessingAccess() noexcept {
    uint32_t expected = 0;
    return flags.compare_exchange_strong(expected, processing, std::memory_order_acq_rel);
  }
  void rt_releaseProcessingAccess() noexcept {
    flags.fetch_and(~processing, std::memory_order_release);
  }
};

// A message-thread-owned pause claim. Independent claims must all be released
// before processing may resume. The last owner also releases on destruction.
class NodeProcessingPause {
  friend class GraphProcessor;
  std::shared_ptr<NodeProcessingState> state;

  void cancel() noexcept {
    if (state)
      state->retire();
    release();
  }
public:
  explicit NodeProcessingPause(std::shared_ptr<NodeProcessingState> state)
    : state(std::move(state)) {
    this->state->requestPause();
  }
  ~NodeProcessingPause() {
    release();
  }
  NodeProcessingPause(const NodeProcessingPause&) = delete;
  NodeProcessingPause& operator=(const NodeProcessingPause&) = delete;

  bool isValid() const noexcept {
    return state && state->phase() != NodeProcessingState::Phase::removed;
  }
  bool isPaused() const noexcept {
    return state && state->phase() == NodeProcessingState::Phase::paused;
  }
  void release() noexcept {
    if (state) {
      state->releasePause();
      state.reset();
    }
  }
};

} // namespace anthem
