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

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>

// Represents one active note owned by a provider.
//
// This stores enough information to emit a matching note-off later after the
// original note-on has already been translated into a runtime live note ID.
namespace anthem {

struct TrackedNote {
  int64_t inputId = -1;
  LiveNoteId liveId = invalidLiveNoteId;
  int16_t pitch = 0;
  int16_t channel = 0;
};

// Fixed-capacity real-time note tracker for active notes.
//
// Providers use this to map their upstream note identity to the emitted live
// note ID while also remembering pitch and channel for later stop events.
// Entries are removed with swap-remove because ordering does not matter.
template <size_t Capacity> class NoteTracker {
public:
  bool rt_add(int64_t inputId, LiveNoteId liveId, int16_t pitch, int16_t channel) {
    if (rt_size >= Capacity) {
      rt_overflowCount++;
      return false;
    }

    rt_notes[rt_size] = TrackedNote{
        .inputId = inputId,
        .liveId = liveId,
        .pitch = pitch,
        .channel = channel,
    };
    rt_size++;

    if (rt_size > rt_highWaterMark) {
      rt_highWaterMark = rt_size;
    }

    return true;
  }

  std::optional<TrackedNote> rt_takeByInputId(int64_t inputId) {
    for (size_t i = 0; i < rt_size; ++i) {
      if (rt_notes[i].inputId != inputId) {
        continue;
      }

      auto tracked = rt_notes[i];
      rt_notes[i] = rt_notes[rt_size - 1];
      rt_size--;
      return tracked;
    }

    return std::nullopt;
  }

  template <typename Callback> void rt_takeAll(Callback&& callback) {
    while (rt_size > 0) {
      auto tracked = rt_notes[rt_size - 1];
      rt_size--;
      callback(tracked);
    }
  }

  void rt_clear() {
    rt_size = 0;
  }

  size_t rt_getSize() const {
    return rt_size;
  }

  size_t rt_getHighWaterMark() const {
    return rt_highWaterMark;
  }

  size_t rt_getOverflowCount() const {
    return rt_overflowCount;
  }
private:
  std::array<TrackedNote, Capacity> rt_notes{};
  size_t rt_size = 0;
  size_t rt_highWaterMark = 0;
  size_t rt_overflowCount = 0;
};

} // namespace anthem
