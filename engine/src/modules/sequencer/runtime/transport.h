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

#pragma once

#include <atomic>
#include <cstdint>
#include <optional>

#include "../time.h"

#include "modules/util/double_buffered_value.h"

class Transport {
public:
  DoubleBufferedValue<std::optional<std::string>> activeSequenceId;

  AnthemSequenceTime rt_playhead;

  std::atomic<int64_t> ticksPerQuarter;
  std::atomic<double> beatsPerMinute;

  Transport() {
    rt_playhead.ticks = 0;
    rt_playhead.fraction = 0.0;
  }
};
