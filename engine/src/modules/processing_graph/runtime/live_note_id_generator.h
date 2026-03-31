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

#include <cstdint>

#include "modules/sequencer/events/note_instance_id.h"

class LiveNoteIdGenerator {
public:
  AnthemLiveNoteId rt_allocate() {
    auto liveNoteId = static_cast<AnthemLiveNoteId>(rt_nextLiveNoteIdCounter);

    if (rt_nextLiveNoteIdCounter >= 0x7ffffffeu) {
      rt_nextLiveNoteIdCounter = 0;
    }
    else {
      rt_nextLiveNoteIdCounter++;
    }

    return liveNoteId;
  }

  void reset() {
    rt_nextLiveNoteIdCounter = 0;
  }

private:
  uint32_t rt_nextLiveNoteIdCounter = 0;
};
