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

#include "modules/sequencer/events/note_instance_id.h"

#include <atomic>
#include <cstdint>

namespace anthem {

class LiveNoteIdGenerator {
public:
  LiveNoteId rt_allocate() {
    auto currentCounter = rt_nextLiveNoteIdCounter.load(std::memory_order_relaxed);

    while (true) {
      const auto nextCounter = currentCounter >= maxLiveNoteId ? 0 : currentCounter + 1;

      if (rt_nextLiveNoteIdCounter.compare_exchange_weak(
              currentCounter, nextCounter, std::memory_order_relaxed, std::memory_order_relaxed)) {
        return static_cast<LiveNoteId>(currentCounter);
      }
    }
  }

  void reset() {
    rt_nextLiveNoteIdCounter.store(0, std::memory_order_relaxed);
  }
private:
  static constexpr uint32_t maxLiveNoteId = 0x7ffffffeu;

  std::atomic<uint32_t> rt_nextLiveNoteIdCounter = 0;
};

} // namespace anthem
