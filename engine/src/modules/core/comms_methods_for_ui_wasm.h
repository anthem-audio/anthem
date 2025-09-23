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

#ifdef __EMSCRIPTEN__

#include <cstdint>

// These methods are meant to be called by the UI to interface with the comms
// layer.

extern "C" bool isCommsReady(int arg);

extern "C" void* getWriteBufferHeadPtr();
extern "C" void* getWriteBufferTailPtr();
extern "C" uint32_t getWriteBufferCapacity();
extern "C" uint32_t getWriteBufferMask();
extern "C" void* getWriteBufferDataPtr();
extern "C" void* getWriteBufferTicketPtr();

extern "C" void* getReadBufferHeadPtr();
extern "C" void* getReadBufferTailPtr();
extern "C" uint32_t getReadBufferCapacity();
extern "C" uint32_t getReadBufferMask();
extern "C" void* getReadBufferDataPtr();
extern "C" void* getReadBufferTicketPtr();

#endif // #ifdef __EMSCRIPTEN__
