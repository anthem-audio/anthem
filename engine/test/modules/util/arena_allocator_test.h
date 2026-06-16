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

#include "modules/util/arena_allocator.h"

#include <juce_core/juce_core.h>
#include <stdexcept>

namespace anthem {

class ArenaAllocatorTest : public juce::UnitTest {
  ArenaAllocator::Handle expectAllocate(
      ArenaAllocator& allocator, size_t blockCount, const juce::String& context) {
    auto handle = allocator.allocate(blockCount);
    expect(handle.has_value(), context + " should allocate.");

    if (handle.has_value()) {
      return *handle;
    }

    return ArenaAllocator::Handle{};
  }
public:
  ArenaAllocatorTest() : juce::UnitTest("ArenaAllocatorTest", "Anthem") {}

  void runTest() override {
    testRejectsInvalidSizing();
    testComputesStorageFromSizingParameters();
    testAllocatesNonOverlappingQuantizedBlocks();
    testRejectsOversizedAndExcessAllocations();
    testFreeReusesStorageAndInvalidatesHandle();
    testAdjacentFreesCoalesce();
    testExplicitFragmentationCushionAllowsLargerAllocations();
    testResetRestoresInitialStateAndInvalidatesHandles();
  }

  void testRejectsInvalidSizing() {
    beginTest("ArenaAllocator rejects invalid sizing parameters");

    expectThrowsType(
        []() {
          ArenaAllocator allocator(0, 4);
        }(),
        std::invalid_argument);
    expectThrowsType(
        []() {
          ArenaAllocator allocator(16, 0);
        }(),
        std::invalid_argument);
  }

  void testComputesStorageFromSizingParameters() {
    beginTest("ArenaAllocator computes storage from sizing parameters");

    ArenaAllocator allocator(32, 24);

    expectEquals(static_cast<int>(allocator.getBlockQuantumSizeBytes()), 32);
    expectEquals(static_cast<int>(allocator.getTotalBlockCount()), 24);
    expectEquals(static_cast<int>(allocator.getStorageSizeBytes()), 768);
    expectEquals(static_cast<int>(allocator.getFreeBlockCapacity()), 25);
    expectEquals(static_cast<int>(allocator.getAllocationRecordCapacity()), 24);
    expectEquals(static_cast<int>(allocator.getFreeBlockCount()), 1);
  }

  void testAllocatesNonOverlappingQuantizedBlocks() {
    beginTest("ArenaAllocator allocates non-overlapping quantized blocks");

    ArenaAllocator allocator(16, 8);

    auto first = expectAllocate(allocator, 1, "First allocation");
    auto second = expectAllocate(allocator, 3, "Second allocation");
    auto third = expectAllocate(allocator, 2, "Third allocation");

    expectEquals(static_cast<int>(allocator.getOffsetBlocks(first)), 0);
    expectEquals(static_cast<int>(allocator.getOffsetBlocks(second)), 1);
    expectEquals(static_cast<int>(allocator.getOffsetBlocks(third)), 4);
    expectEquals(static_cast<int>(allocator.getBlockCount(second)), 3);
    expect(allocator.getPointer(first) != nullptr, "First allocation should have a pointer.");
    expect(allocator.getPointer(second) == allocator.getPointer(first) + 16,
        "The second pointer should advance by one quantum.");
    expectEquals(static_cast<int>(allocator.getActiveAllocationCount()), 3);
  }

  void testRejectsOversizedAndExcessAllocations() {
    beginTest("ArenaAllocator rejects oversized allocations and exhausted storage");

    ArenaAllocator allocator(16, 2);

    expect(!allocator.allocate(0).has_value(), "Zero-block allocations should be rejected.");
    expect(!allocator.allocate(3).has_value(),
        "Allocations larger than the arena should be rejected.");

    auto first = allocator.allocate(1);
    auto second = allocator.allocate(1);
    auto third = allocator.allocate(1);

    expect(first.has_value(), "First single-block allocation should fit.");
    expect(second.has_value(), "Second single-block allocation should fit.");
    expect(!third.has_value(), "Allocations beyond arena capacity should fail.");
  }

  void testFreeReusesStorageAndInvalidatesHandle() {
    beginTest("ArenaAllocator frees, reuses storage, and invalidates old handles");

    ArenaAllocator allocator(16, 4);

    auto first = expectAllocate(allocator, 2, "First allocation");
    auto second = expectAllocate(allocator, 2, "Second allocation");
    auto firstPointer = allocator.getPointer(first);

    expect(allocator.free(first), "Free should succeed for a live handle.");
    expect(!allocator.owns(first), "Freed handles should be invalid.");
    expect(allocator.getPointer(first) == nullptr, "Freed handles should not return pointers.");
    expect(!allocator.free(first), "Double free should fail.");

    auto third = expectAllocate(allocator, 2, "Third allocation");

    expect(allocator.getPointer(third) == firstPointer,
        "A same-sized allocation should reuse the freed span.");
    expect(third != first, "Reused allocation records should receive a new generation.");
    expect(allocator.owns(second), "Other live handles should remain valid.");
  }

  void testAdjacentFreesCoalesce() {
    beginTest("ArenaAllocator coalesces adjacent freed blocks");

    ArenaAllocator allocator(16, 8);

    auto first = expectAllocate(allocator, 2, "First allocation");
    auto second = expectAllocate(allocator, 2, "Second allocation");
    auto third = expectAllocate(allocator, 2, "Third allocation");

    expect(allocator.free(second), "Middle free should succeed.");
    expectEquals(static_cast<int>(allocator.getFreeBlockCount()),
        2,
        "Freeing the middle block should create a second free span.");

    expect(allocator.free(first), "Freeing the previous block should coalesce with the middle.");
    expectEquals(
        static_cast<int>(allocator.getFreeBlockCount()), 2, "Adjacent free spans should coalesce.");

    auto merged = expectAllocate(allocator, 4, "Merged allocation");
    expectEquals(static_cast<int>(allocator.getOffsetBlocks(merged)),
        0,
        "Merged allocation should reuse the coalesced front span.");

    expect(allocator.free(third), "Remaining original allocation should still free cleanly.");
    expect(allocator.free(merged), "Merged allocation should free cleanly.");
    expectEquals(static_cast<int>(allocator.getFreeBlockCount()),
        1,
        "Freeing all allocations should restore one free span.");
  }

  void testExplicitFragmentationCushionAllowsLargerAllocations() {
    beginTest("ArenaAllocator uses explicit capacity for fragmentation cushions");

    ArenaAllocator allocator(16, 24);

    auto first = expectAllocate(allocator, 3, "First allocation");
    auto second = expectAllocate(allocator, 3, "Second allocation");
    auto third = expectAllocate(allocator, 3, "Third allocation");

    expect(allocator.free(second), "Freeing the middle allocation should fragment the arena.");

    auto maxAllocation = allocator.allocate(4);

    expect(maxAllocation.has_value(),
        "The caller-provided sizing cushion should leave room for a max-sized allocation.");
    expectEquals(static_cast<int>(allocator.getActiveAllocationCount()), 3);

    expect(allocator.free(first), "First allocation should free.");
    expect(allocator.free(third), "Third allocation should free.");
    expect(allocator.free(*maxAllocation), "Max allocation should free.");
  }

  void testResetRestoresInitialStateAndInvalidatesHandles() {
    beginTest("ArenaAllocator reset restores the initial state and invalidates handles");

    ArenaAllocator allocator(16, 8);

    auto first = expectAllocate(allocator, 2, "First allocation");
    auto second = expectAllocate(allocator, 2, "Second allocation");

    allocator.reset();

    expect(!allocator.owns(first), "Reset should invalidate the first handle.");
    expect(!allocator.owns(second), "Reset should invalidate the second handle.");
    expectEquals(static_cast<int>(allocator.getActiveAllocationCount()), 0);
    expectEquals(static_cast<int>(allocator.getFreeBlockCount()), 1);

    auto afterReset = expectAllocate(allocator, 4, "Post-reset allocation");
    expectEquals(static_cast<int>(allocator.getOffsetBlocks(afterReset)),
        0,
        "Post-reset allocation should start at the beginning of the arena.");
  }
};

static ArenaAllocatorTest arenaAllocatorTest;

} // namespace anthem
