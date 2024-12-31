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

#include <cstdlib>
#include <new>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <juce_core/juce_core.h>
#include <vector>

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

// A simple, real-time safe arena allocator for dynamically allocating buffers
// of a given type.
//
// This class allocates a fixed-size memory region ahead of time. Consumers can
// then call `allocate()` to allocate a buffer of a given size. Since the memory
// is pre-allocated, this class is real-time safe.
//
// A couple notes:
//
// - When this class is deallocated, the memory is freed. However, no
//   destructors are called. If data stored in the arena needs to be cleaned up,
//   it must be cleaned up before the arena is deallocated.
//
// - If the arena runs out of space, a new arena is allocated. This is not
//   real-time safe, so the original arena shuold sized so that this does not
//   happen under most circumstances.
template<typename T>
class ArenaBufferAllocator {
private:
  // The size of each arena buffer in bytes.
  size_t arenaSizeInBytes;

  // The amount of memory that has been freed since the last coalesce.
  size_t freedAmountSinceLastCoalesce = 0;

  // A list of void* pointers to arenas that have been allocated, each with a
  // size of arenaSizeInBytes.
  //
  // We have a list in case the first buffer overflows. Since this is used on
  // the audio thread, the first buffer should only overflow in extreme
  // circumstances, since overflowing will result in additional memory
  // allocation, which is not real-time safe.
  std::vector<void*> arenas;

  // The minimum size of each arena buffer in bytes.
  const size_t minArenaSize = 1024;

  void markFree(void* position, size_t sizeInBytes);

  // Allocates memory in an arena.
  ArenaBufferAllocateResult<T> allocateInArena(void* arena, size_t numItems);

  // Coalesces the arena, merging adjacent free sections.
  void coalesceInArena(void* arena);
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

  // Returns the number of arenas that have been allocated. This should be 1 in
  // normal circumstances.
  unsigned int getArenaCount();
};

template<typename T>
void ArenaBufferAllocator<T>::markFree(void* position, size_t sizeInBytes) {
  *reinterpret_cast<size_t*>(position) = sizeInBytes;
  *reinterpret_cast<bool*>(static_cast<uint8_t*>(position) + sizeof(size_t)) = false;
}

template<typename T>
ArenaBufferAllocator<T>::ArenaBufferAllocator(size_t arenaSizeInBytes) {
  auto arenaSize = std::max(arenaSizeInBytes, this->minArenaSize);

  this->arenaSizeInBytes = arenaSize;

  auto ptr = malloc(arenaSize);

  if (ptr == nullptr) {
    throw std::bad_alloc();
  }

  this->arenas.push_back(ptr);

  this->markFree(ptr, arenaSize);
}

template<typename T>
ArenaBufferAllocator<T>::~ArenaBufferAllocator() {
  for (auto arena : this->arenas) {
    free(arena);
  }
}

template<typename T>
ArenaBufferAllocateResult<T> ArenaBufferAllocator<T>::allocateInArena(void* arena, size_t numItems) {
  void* regionStart = arena;
  while (regionStart < static_cast<uint8_t*>(arena) + this->arenaSizeInBytes) {
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
ArenaBufferAllocateResult<T> ArenaBufferAllocator<T>::allocate(size_t numItems) {
  for (auto arena : this->arenas) {
    auto result = this->allocateInArena(arena, numItems);
    if (result.success) {
      return result;
    }
  }

  // If no arena had enough space, allocate a new one
  auto arenaSize = std::max(this->arenaSizeInBytes, this->minArenaSize);
  auto ptr = malloc(arenaSize);

  if (ptr == nullptr) {
    throw std::bad_alloc();
  }

  this->arenas.push_back(ptr);

  this->markFree(ptr, arenaSize);

  return this->allocateInArena(ptr, numItems);
}

template<typename T>
void ArenaBufferAllocator<T>::deallocate(void* deallocatePtr) {
  void* regionStart = deallocatePtr;

  uint8_t* sizePtr = static_cast<uint8_t*>(regionStart);
  size_t sectionSizeInBytes = *reinterpret_cast<size_t*>(sizePtr);

  *reinterpret_cast<bool*>(sizePtr + sizeof(size_t)) = false;

  this->freedAmountSinceLastCoalesce += sectionSizeInBytes;

  // If we've freed a lot of memory, coalesce the arenas
  if (this->freedAmountSinceLastCoalesce > this->arenaSizeInBytes / 2) {
    this->coalesce();
    this->freedAmountSinceLastCoalesce = 0;
  }
}

template<typename T>
void ArenaBufferAllocator<T>::coalesceInArena(void* arena) {
  void* regionStart = arena;
  while (regionStart < static_cast<uint8_t*>(arena) + this->arenaSizeInBytes) {
    size_t sectionSizeInBytes = *reinterpret_cast<size_t*>(regionStart);
    bool isInUse = *reinterpret_cast<bool*>(static_cast<uint8_t*>(regionStart) + sizeof(size_t));
    if (isInUse) {
      regionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
      continue;
    }

    void* nextRegionStart = static_cast<uint8_t*>(regionStart) + sectionSizeInBytes;
    if (nextRegionStart >= static_cast<uint8_t*>(arena) + this->arenaSizeInBytes) {
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

template<typename T>
void ArenaBufferAllocator<T>::coalesce() {
  for (auto arena : this->arenas) {
    this->coalesceInArena(arena);
  }
}

template<typename T>
unsigned int ArenaBufferAllocator<T>::getArenaCount() {
  return this->arenas.size();
}
