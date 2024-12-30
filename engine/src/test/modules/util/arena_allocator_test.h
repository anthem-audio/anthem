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

#include "modules/util/arena_allocator.h"

struct TestStruct {
  int a;
  short b;
  long c;
  char d;
};

class ArenaAllocatorTest : public juce::UnitTest {
public:
  ArenaAllocatorTest() : juce::UnitTest("ArenaAllocatorTest", "Anthem") {}

  void runTest() override {
    {
      beginTest("Create and delete arena with no allocation");
      auto arena = new ArenaBufferAllocator<int>(1024);
      delete arena;
    }

    {
      beginTest("Simple allocate and deallocate in arena");
      auto arena = new ArenaBufferAllocator<int>(1024);

      auto result = arena->allocate(1);
      expect(result.success, "Allocation succeeded");
      
      result.memoryStart[0] = 5;
      expect(result.memoryStart[0] == 5, "Memory is correct");

      arena->deallocate(result.deallocatePtr);
      auto result2 = arena->allocate(1);
      expect(result2.success, "Re-allocation succeeded");
      expect(result.memoryStart == result2.memoryStart, "Memory is in the same location");

      arena->deallocate(result2.deallocatePtr);
      delete arena;
    }

    {
      beginTest("Allocate and deallocate multiple times in arena");
      auto arena = new ArenaBufferAllocator<int>(1024);

      auto result = arena->allocate(1);
      expect(result.success, "Allocation 1 succeeded");

      auto result2 = arena->allocate(1);
      expect(result2.success, "Allocation 2 succeeded");

      arena->deallocate(result.deallocatePtr);
      auto result3 = arena->allocate(1);
      expect(result3.success, "Re-allocation 1 succeeded");
      expect(result.memoryStart == result3.memoryStart, "Memory is in the same location");

      arena->deallocate(result2.deallocatePtr);
      auto result4 = arena->allocate(1);
      expect(result4.success, "Re-allocation 2 succeeded");

      arena->deallocate(result3.deallocatePtr);
      arena->deallocate(result4.deallocatePtr);
      delete arena;
    }

    {
      beginTest("Test overflow behavior");
      // The actual size will be the minimum size as defined in arena_allocator.h
      auto arena = new ArenaBufferAllocator<TestStruct>(0);

      for (int i = 0; i < 1024; i++) {
        auto result = arena->allocate(1);
        expect(result.success, "Allocation succeeded");
        // Check that we can write to the memory
        result.memoryStart->a = 5;
        arena->deallocate(result.deallocatePtr);
      }

      expect(arena->getArenaCount() == 1, "If everything is deallocated immediately, multiple arenas are not created");

      // This should fill a few buffers. Since each buffer is 1024 bytes, we
      // should be able to allocate 1024 / sizeof(TestStruct) items in each
      // buffer.
      for (int i = 0; i < 1024; i++) {
        auto result = arena->allocate(1);
        expect(result.success, "Allocation succeeded");
        // Check that we can write to the memory
        result.memoryStart->a = 5;
      }

      expect(arena->getArenaCount() > 1, "If we fill the first buffer, a new one is created and nothing bad happens");

      delete arena;
    }

    {
      beginTest("Test allocation errors");

      auto arena = new ArenaBufferAllocator<int>(1024);

      auto result = arena->allocate(1);
      expect(result.success, "Allocation succeeded");

      // This should fail
      auto result2 = arena->allocate(1024);
      expect(!result2.success, "Allocation failed");

      delete arena;
    }

    {
      beginTest("Test allocations of multiple sizes, and test coalescing");

      auto arena = new ArenaBufferAllocator<int>(1024);

      auto result = arena->allocate(3);
      auto result2 = arena->allocate(5);
      arena->deallocate(result.deallocatePtr);
      auto result3 = arena->allocate(1);

      expect(result.success, "Allocation 1 succeeded");
      expect(result2.success, "Allocation 2 succeeded");
      expect(result3.success, "Allocation 3 succeeded");

      expect(result.memoryStart != result2.memoryStart, "Memory is in different locations");
      expect(result.memoryStart == result3.memoryStart, "Memory is in the same location");

      arena->deallocate(result2.deallocatePtr);
      arena->deallocate(result3.deallocatePtr);

      arena->coalesce();

      auto result5 = arena->allocate(15);
      expect(result5.success, "Allocation 5 succeeded");
      expect(result.memoryStart == result5.memoryStart, "After coalescing an empty buffer, new items are allocated at the start");

      arena->coalesce();

      auto result6 = arena->allocate(15);
      expect(result6.success, "Allocation 6 succeeded");
      expect(result5.memoryStart != result6.memoryStart, "After coalescing a non-empty buffer, existing data is not mangled");

      delete arena;
    }
  }
};

static ArenaAllocatorTest arenaAllocatorTest;
