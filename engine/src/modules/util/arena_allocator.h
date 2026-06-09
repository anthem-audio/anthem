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

#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>

#include <juce_core/juce_core.h>

namespace anthem {

class ArenaAllocator {
public:
  struct Handle {
    size_t index = std::numeric_limits<size_t>::max();
    uint32_t generation = 0;

    bool operator==(const Handle& other) const {
      return index == other.index && generation == other.generation;
    }

    bool operator!=(const Handle& other) const {
      return !(*this == other);
    }
  };
private:
  JUCE_LEAK_DETECTOR(ArenaAllocator)

  class Impl;
  std::unique_ptr<Impl> impl;
public:
  ArenaAllocator(size_t blockQuantumSizeBytes,
      size_t maxAllocationBlockCount,
      size_t maxLiveAllocationCount);
  ~ArenaAllocator();

  ArenaAllocator(const ArenaAllocator&) = delete;
  ArenaAllocator& operator=(const ArenaAllocator&) = delete;

  ArenaAllocator(ArenaAllocator&&) = delete;
  ArenaAllocator& operator=(ArenaAllocator&&) = delete;

  std::optional<Handle> allocate(size_t blockCount);
  bool free(Handle handle);
  void reset();

  bool owns(Handle handle) const;
  std::byte* getPointer(Handle handle);
  const std::byte* getPointer(Handle handle) const;
  size_t getBlockCount(Handle handle) const;
  size_t getOffsetBlocks(Handle handle) const;

  size_t getBlockQuantumSizeBytes() const;
  size_t getMaxAllocationBlockCount() const;
  size_t getMaxLiveAllocationCount() const;
  size_t getTotalBlockCount() const;
  size_t getStorageSizeBytes() const;
  size_t getFreeBlockCount() const;
  size_t getFreeBlockCapacity() const;
  size_t getAllocationRecordCapacity() const;
  size_t getActiveAllocationCount() const;
};

} // namespace anthem
