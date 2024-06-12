/*
  Copyright (C) 2024 Joshua Wade

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

// This is a thread-safe ID generator. It is used to generate unique IDs for
// various objects in the Anthem engine.
//
// We don't use UUID here because we won't ever need to generate IDs across
// multiple machines. If Anthem were to ever support multi-user editing, the
// synchronization would happen in the UI process and the engine wouldn't need
// to worry about it.
class GlobalIDGenerator {
public:
    static uint64_t generateID();
};
