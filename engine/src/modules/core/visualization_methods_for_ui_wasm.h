/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#pragma once

#ifdef __EMSCRIPTEN__

#include <cstdint>

extern "C" int32_t tryAcquireVisualizationRecord() noexcept;
extern "C" const void* getAcquiredVisualizationRecordData() noexcept;
extern "C" uint32_t getAcquiredVisualizationRecordSize() noexcept;
extern "C" uint32_t getVisualizationRecordAvailableBytes() noexcept;
extern "C" int32_t releaseVisualizationRecord() noexcept;

#endif // #ifdef __EMSCRIPTEN__
