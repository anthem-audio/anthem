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

// Result of an allocation. `success` will be true if the allocation succeeded,
// and memoryStart will be the start of the allocated array.
//
// If you ever want to deallocate the memory, pass deallocatePtr to
// `ArenaBufferAllocator::free()`.
template <typename T>
struct ArenaBufferAllocateResult {
  bool success;
  T* memoryStart;
  void* deallocatePtr;
};

// A simple arena allocator for variable-size buffers.
//
// This class allocates a fixed-size buffer, and allows that buffer to be used
// for allocating arrays of type T. The type must be known ahead of time to
// ensure correct memory alignment.
//
// Note:
//
// When this class is deallocated, the memory is freed. However, no destructors
// are called. If data stored in the arena needs to be cleaned up, it must be
// cleaned up before the arena is deallocated.
template<typename T>
class ArenaBufferAllocator {
private:
  size_t arenaSizeInBytes;
  void* arena;
  const size_t minArenaSize = 1024;

  void markFree(void* position, size_t sizeInBytes);
public:
  // Creates an ArenaBufferAllocator. arenaSizeInBytes is the size of the arena
  // in bytes.
  ArenaBufferAllocator(size_t arenaSizeInBytes);
  ~ArenaBufferAllocator();

  // Allocates memory in the arena.
  ArenaBufferAllocateResult<T> allocate(size_t numItems);

  // Frees the memory chunk at the given address. This is expected to be a
  // deallocatePtr returned from allocate().
  void deallocate(void* deallocatePtr);

  // Coalesces the arena, merging adjacent free sections.
  void coalesce();
};

#include <cstdlib>
#include <new>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <juce_core/juce_core.h>

template<typename T>
void ArenaBufferAllocator<T>::markFree(void* position, size_t sizeInBytes) {
  *reinterpret_cast<size_t*>(position) = sizeInBytes;
  *reinterpret_cast<bool*>(static_cast<uint8_t*>(position) + sizeof(size_t)) = false;
}

template<typename T>
ArenaBufferAllocator<T>::ArenaBufferAllocator(size_t arenaSizeInBytes) {
  auto arenaSize = std::max(arenaSizeInBytes, this->minArenaSize);

  this->arenaSizeInBytes = arenaSize;

  this->arena = malloc(arenaSize);

  if (this->arena == nullptr) {
    throw std::bad_alloc();
  }

  this->markFree(this->arena, arenaSize);
}

template<typename T>
ArenaBufferAllocator<T>::~ArenaBufferAllocator() {
  free(this->arena);
}

template<typename T>
ArenaBufferAllocateResult<T> ArenaBufferAllocator<T>::allocate(size_t numItems) {
  void* regionStart = this->arena;
  while (regionStart < static_cast<uint8_t*>(this->arena) + this->arenaSizeInBytes) {
    size_t sectionSizeInBytes = *reinterpret_cast<size_t*>(regionStart);

    // Check if the section is in use
    bool isInUse = *reinterpret_cast<bool*>(static_cast<uint8_t*>(regionStart) + sizeof(size_t));
    if (isInUse) {
      regionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
      continue;
    }

    // Calculate the start of the section, accounting for metadata
    void* sectionStart = static_cast<uint8_t*>(regionStart) + sizeof(size_t) + sizeof(bool);
    size_t alignment = alignof(T);
    
    // Adjust the available size for alignment, subtracting metadata
    size_t adjustedSize = sectionSizeInBytes - sizeof(size_t) - sizeof(bool);
    size_t adjustedSizeOriginal = adjustedSize;

    // Check if the section can be aligned and has enough space
    if (std::align(alignment, sizeof(T) * numItems, sectionStart, adjustedSize)) {
      auto sizeAdjustmentAmount = adjustedSizeOriginal - adjustedSize;

      size_t requiredSize = sizeof(T) * numItems;
      if (adjustedSize >= requiredSize) {
        auto newSectionSize = sizeof(size_t) + sizeof(bool) + sizeAdjustmentAmount + requiredSize;

        // Calculate the start of the free section after the allocated memory
        auto nextSectionStart = static_cast<uint8_t*>(regionStart) + newSectionSize;
        auto nextSectionSize = sectionSizeInBytes - newSectionSize;

        // Write a new size for the section
        *reinterpret_cast<size_t*>(regionStart) = newSectionSize;

        // Mark the section as in use
        *reinterpret_cast<bool*>(static_cast<uint8_t*>(regionStart) + sizeof(size_t)) = true;

        // If there is enough space for a new section, mark it as free
        if (nextSectionSize >= sizeof(size_t) + sizeof(bool)) {
          // Mark the next section as free
          this->markFree(
            nextSectionStart,
            nextSectionSize
          );
        } else if (nextSectionSize > 0) {
          // If there is not enough space for a new section, make sure that the
          // current section's size includes the remaining space
          *reinterpret_cast<size_t*>(regionStart) = sectionSizeInBytes;
        }

        // Return the memory
        return { true, reinterpret_cast<T*>(sectionStart), regionStart };
      }
    }

    jassert(sectionSizeInBytes > 0);

    // If this section didn't work, move to the next one
    regionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
  }

  // If no section was found, return a failure
  return { false, nullptr, nullptr };
}

template<typename T>
void ArenaBufferAllocator<T>::deallocate(void* deallocatePtr) {
  void* regionStart = deallocatePtr;
  *reinterpret_cast<bool*>(static_cast<uint8_t*>(regionStart) + sizeof(size_t)) = false;
}

template<typename T>
void ArenaBufferAllocator<T>::coalesce() {
  void* regionStart = this->arena;
  while (regionStart < static_cast<uint8_t*>(this->arena) + this->arenaSizeInBytes) {
    size_t sectionSizeInBytes = *reinterpret_cast<size_t*>(regionStart);
    bool isInUse = *reinterpret_cast<bool*>(static_cast<uint8_t*>(regionStart) + sizeof(size_t));
    if (isInUse) {
      regionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
      continue;
    }

    void* nextRegionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
    if (nextRegionStart >= static_cast<uint8_t*>(this->arena) + this->arenaSizeInBytes) {
      break;
    }

    size_t nextSectionSizeInBytes = *reinterpret_cast<size_t*>(nextRegionStart);
    bool isNextInUse = *reinterpret_cast<bool*>(static_cast<uint8_t*>(nextRegionStart) + sizeof(size_t));

    if (!isNextInUse) {
      size_t newSize = sectionSizeInBytes + nextSectionSizeInBytes;
      *reinterpret_cast<size_t*>(regionStart) = newSize;
      continue;  // Stay at the current regionStart to check for further coalescing
    }

    jassert(nextRegionStart != regionStart);

    regionStart = nextRegionStart;
  }
}
