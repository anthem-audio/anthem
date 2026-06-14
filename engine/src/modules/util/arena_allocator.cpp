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

#include "arena_allocator.h"

#include <stdexcept>
#include <vector>

namespace anthem {

class ArenaAllocator::Impl {
private:
  struct FreeBlock {
    size_t offsetBlocks = 0;
    size_t blockCount = 0;
  };

  struct AllocationRecord {
    size_t offsetBlocks = 0;
    size_t blockCount = 0;
    uint32_t generation = 0;
    bool active = false;
  };

  static constexpr size_t invalidIndex = std::numeric_limits<size_t>::max();

  static size_t checkedMultiply(size_t a, size_t b, const char* context) {
    if (a != 0 && b > std::numeric_limits<size_t>::max() / a) {
      throw std::overflow_error(context);
    }

    return a * b;
  }

  static uint32_t nextGeneration(uint32_t generation) {
    generation++;

    if (generation == 0) {
      generation = 1;
    }

    return generation;
  }

  bool isHandleValid(Handle handle) const {
    if (handle.index >= allocationRecords.size()) {
      return false;
    }

    const auto& record = allocationRecords[handle.index];
    return record.active && record.generation == handle.generation;
  }

  void removeFreeBlock(size_t index) {
    jassert(index < freeBlockCount);

    for (size_t i = index + 1; i < freeBlockCount; ++i) {
      freeBlocks[i - 1] = freeBlocks[i];
    }

    freeBlockCount--;
  }

  bool insertFreeBlock(size_t offsetBlocks, size_t blockCount) {
    size_t insertIndex = 0;

    while (insertIndex < freeBlockCount && freeBlocks[insertIndex].offsetBlocks < offsetBlocks) {
      insertIndex++;
    }

    if (insertIndex > 0) {
      auto& previous = freeBlocks[insertIndex - 1];
      const auto previousEnd = previous.offsetBlocks + previous.blockCount;

      if (previousEnd == offsetBlocks) {
        previous.blockCount += blockCount;

        if (insertIndex < freeBlockCount) {
          auto& next = freeBlocks[insertIndex];
          const auto mergedEnd = previous.offsetBlocks + previous.blockCount;

          if (mergedEnd == next.offsetBlocks) {
            previous.blockCount += next.blockCount;
            removeFreeBlock(insertIndex);
          }
        }

        return true;
      }
    }

    if (insertIndex < freeBlockCount) {
      auto& next = freeBlocks[insertIndex];
      const auto insertedEnd = offsetBlocks + blockCount;

      if (insertedEnd == next.offsetBlocks) {
        next.offsetBlocks = offsetBlocks;
        next.blockCount += blockCount;
        return true;
      }
    }

    if (freeBlockCount >= freeBlocks.size()) {
      jassertfalse;
      return false;
    }

    for (size_t i = freeBlockCount; i > insertIndex; --i) {
      freeBlocks[i] = freeBlocks[i - 1];
    }

    freeBlocks[insertIndex] = FreeBlock{
        .offsetBlocks = offsetBlocks,
        .blockCount = blockCount,
    };
    freeBlockCount++;

    return true;
  }

  size_t blockQuantumSizeBytes = 0;
  size_t maxAllocationBlockCount = 0;
  size_t maxLiveAllocationCount = 0;
  size_t totalBlockCount = 0;

  std::vector<std::byte> storage;
  std::vector<FreeBlock> freeBlocks;
  std::vector<AllocationRecord> allocationRecords;
  std::vector<size_t> freeAllocationIndices;

  size_t freeBlockCount = 0;
  size_t freeAllocationIndexCount = 0;
  size_t activeAllocationCount = 0;
public:
  Impl(size_t blockQuantumSizeBytes, size_t maxAllocationBlockCount, size_t maxLiveAllocationCount)
    : blockQuantumSizeBytes(blockQuantumSizeBytes),
      maxAllocationBlockCount(maxAllocationBlockCount),
      maxLiveAllocationCount(maxLiveAllocationCount) {
    if (blockQuantumSizeBytes == 0) {
      throw std::invalid_argument("ArenaAllocator block quantum size must be greater than zero.");
    }

    if (maxAllocationBlockCount == 0) {
      throw std::invalid_argument(
          "ArenaAllocator max allocation block count must be greater than zero.");
    }

    if (maxLiveAllocationCount == 0) {
      throw std::invalid_argument(
          "ArenaAllocator max live allocation count must be greater than zero.");
    }

    totalBlockCount = checkedMultiply(checkedMultiply(maxAllocationBlockCount,
                                          maxLiveAllocationCount,
                                          "ArenaAllocator total block count overflowed."),
        static_cast<size_t>(2),
        "ArenaAllocator total block count overflowed.");
    const auto storageByteCount = checkedMultiply(
        totalBlockCount, blockQuantumSizeBytes, "ArenaAllocator storage size overflowed.");

    storage.resize(storageByteCount);
    freeBlocks.resize(maxLiveAllocationCount + 1);
    allocationRecords.resize(maxLiveAllocationCount);
    freeAllocationIndices.resize(maxLiveAllocationCount);

    reset();
  }

  std::optional<Handle> allocate(size_t blockCount) {
    if (blockCount == 0 || blockCount > maxAllocationBlockCount || freeAllocationIndexCount == 0) {
      return std::nullopt;
    }

    for (size_t freeBlockIndex = 0; freeBlockIndex < freeBlockCount; ++freeBlockIndex) {
      auto& freeBlock = freeBlocks[freeBlockIndex];

      if (freeBlock.blockCount < blockCount) {
        continue;
      }

      const auto recordIndex = freeAllocationIndices[freeAllocationIndexCount - 1];
      freeAllocationIndexCount--;

      auto& record = allocationRecords[recordIndex];
      record.offsetBlocks = freeBlock.offsetBlocks;
      record.blockCount = blockCount;
      record.generation = nextGeneration(record.generation);
      record.active = true;

      if (freeBlock.blockCount == blockCount) {
        removeFreeBlock(freeBlockIndex);
      } else {
        freeBlock.offsetBlocks += blockCount;
        freeBlock.blockCount -= blockCount;
      }

      activeAllocationCount++;

      return Handle{
          .index = recordIndex,
          .generation = record.generation,
      };
    }

    return std::nullopt;
  }

  bool free(Handle handle) {
    if (!isHandleValid(handle)) {
      return false;
    }

    auto& record = allocationRecords[handle.index];

    if (!insertFreeBlock(record.offsetBlocks, record.blockCount)) {
      return false;
    }

    record.active = false;
    record.offsetBlocks = 0;
    record.blockCount = 0;

    jassert(freeAllocationIndexCount < freeAllocationIndices.size());
    freeAllocationIndices[freeAllocationIndexCount] = handle.index;
    freeAllocationIndexCount++;

    jassert(activeAllocationCount > 0);
    activeAllocationCount--;

    return true;
  }

  void reset() {
    freeBlockCount = 1;
    freeBlocks[0] = FreeBlock{
        .offsetBlocks = 0,
        .blockCount = totalBlockCount,
    };

    freeAllocationIndexCount = allocationRecords.size();
    activeAllocationCount = 0;

    for (size_t i = 0; i < allocationRecords.size(); ++i) {
      auto& record = allocationRecords[i];
      record.offsetBlocks = 0;
      record.blockCount = 0;
      record.generation = nextGeneration(record.generation);
      record.active = false;
      freeAllocationIndices[i] = allocationRecords.size() - i - 1;
    }
  }

  bool owns(Handle handle) const {
    return isHandleValid(handle);
  }

  std::byte* getPointer(Handle handle) {
    if (!isHandleValid(handle)) {
      return nullptr;
    }

    return storage.data() + allocationRecords[handle.index].offsetBlocks * blockQuantumSizeBytes;
  }

  const std::byte* getPointer(Handle handle) const {
    if (!isHandleValid(handle)) {
      return nullptr;
    }

    return storage.data() + allocationRecords[handle.index].offsetBlocks * blockQuantumSizeBytes;
  }

  size_t getBlockCount(Handle handle) const {
    if (!isHandleValid(handle)) {
      return 0;
    }

    return allocationRecords[handle.index].blockCount;
  }

  size_t getOffsetBlocks(Handle handle) const {
    if (!isHandleValid(handle)) {
      return invalidIndex;
    }

    return allocationRecords[handle.index].offsetBlocks;
  }

  size_t getBlockQuantumSizeBytes() const {
    return blockQuantumSizeBytes;
  }

  size_t getMaxAllocationBlockCount() const {
    return maxAllocationBlockCount;
  }

  size_t getMaxLiveAllocationCount() const {
    return maxLiveAllocationCount;
  }

  size_t getTotalBlockCount() const {
    return totalBlockCount;
  }

  size_t getStorageSizeBytes() const {
    return storage.size();
  }

  size_t getFreeBlockCount() const {
    return freeBlockCount;
  }

  size_t getFreeBlockCapacity() const {
    return freeBlocks.size();
  }

  size_t getAllocationRecordCapacity() const {
    return allocationRecords.size();
  }

  size_t getActiveAllocationCount() const {
    return activeAllocationCount;
  }
};

ArenaAllocator::ArenaAllocator(
    size_t blockQuantumSizeBytes, size_t maxAllocationBlockCount, size_t maxLiveAllocationCount)
  : impl(std::make_unique<Impl>(
        blockQuantumSizeBytes, maxAllocationBlockCount, maxLiveAllocationCount)) {}

ArenaAllocator::~ArenaAllocator() = default;

std::optional<ArenaAllocator::Handle> ArenaAllocator::allocate(size_t blockCount) {
  return impl->allocate(blockCount);
}

bool ArenaAllocator::free(Handle handle) {
  return impl->free(handle);
}

void ArenaAllocator::reset() {
  impl->reset();
}

bool ArenaAllocator::owns(Handle handle) const {
  return impl->owns(handle);
}

std::byte* ArenaAllocator::getPointer(Handle handle) {
  return impl->getPointer(handle);
}

const std::byte* ArenaAllocator::getPointer(Handle handle) const {
  return impl->getPointer(handle);
}

size_t ArenaAllocator::getBlockCount(Handle handle) const {
  return impl->getBlockCount(handle);
}

size_t ArenaAllocator::getOffsetBlocks(Handle handle) const {
  return impl->getOffsetBlocks(handle);
}

size_t ArenaAllocator::getBlockQuantumSizeBytes() const {
  return impl->getBlockQuantumSizeBytes();
}

size_t ArenaAllocator::getMaxAllocationBlockCount() const {
  return impl->getMaxAllocationBlockCount();
}

size_t ArenaAllocator::getMaxLiveAllocationCount() const {
  return impl->getMaxLiveAllocationCount();
}

size_t ArenaAllocator::getTotalBlockCount() const {
  return impl->getTotalBlockCount();
}

size_t ArenaAllocator::getStorageSizeBytes() const {
  return impl->getStorageSizeBytes();
}

size_t ArenaAllocator::getFreeBlockCount() const {
  return impl->getFreeBlockCount();
}

size_t ArenaAllocator::getFreeBlockCapacity() const {
  return impl->getFreeBlockCapacity();
}

size_t ArenaAllocator::getAllocationRecordCapacity() const {
  return impl->getAllocationRecordCapacity();
}

size_t ArenaAllocator::getActiveAllocationCount() const {
  return impl->getActiveAllocationCount();
}

} // namespace anthem
