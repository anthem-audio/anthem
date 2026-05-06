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

#include "modules/util/ring_buffer.h"

#include <juce_core/juce_core.h>

namespace anthem {

class RingBufferTest : public juce::UnitTest {
  template <std::size_t Size>
  void expectReadValue(RingBuffer<int, Size>& buffer, int expected, const juce::String& context) {
    auto value = buffer.read();
    expect(value.has_value(), context + " should return a value");
    if (value.has_value()) {
      expectEquals(value.value(), expected, context + " should preserve FIFO ordering");
    }
  }
public:
  RingBufferTest() : juce::UnitTest("RingBufferTest", "Anthem") {}

  void runTest() override {
    testFifoBehavior();
    testEmptyAndFullBehavior();
    testWraparoundBehavior();
    testOverflowDoesNotOverwriteQueuedItems();
  }

  void testFifoBehavior() {
    beginTest("Ring buffer preserves FIFO ordering");

    RingBuffer<int, 4> buffer;

    expect(buffer.add(10), "First value should be added");
    expect(buffer.add(20), "Second value should be added");
    expect(buffer.add(30), "Third value should be added");

    expectReadValue(buffer, 10, "First read");
    expectReadValue(buffer, 20, "Second read");
    expectReadValue(buffer, 30, "Third read");
  }

  void testEmptyAndFullBehavior() {
    beginTest("Ring buffer reports empty and full states");

    RingBuffer<int, 2> buffer;

    expect(!buffer.read().has_value(), "Reading an empty buffer should return nullopt");

    expect(buffer.add(1), "First slot should be writable");
    expect(buffer.add(2), "Second slot should be writable");
    expect(!buffer.add(3), "Adding to a full buffer should fail");

    expectReadValue(buffer, 1, "First full-buffer read");
    expectReadValue(buffer, 2, "Second full-buffer read");
    expect(!buffer.read().has_value(), "Reading after draining should return nullopt");
  }

  void testWraparoundBehavior() {
    beginTest("Ring buffer preserves FIFO order across wraparound");

    RingBuffer<int, 4> buffer;

    expect(buffer.add(1), "First value should be added");
    expect(buffer.add(2), "Second value should be added");
    expect(buffer.add(3), "Third value should be added");

    expectReadValue(buffer, 1, "Initial read one");
    expectReadValue(buffer, 2, "Initial read two");

    expect(buffer.add(4), "Fourth value should fit after wraparound");
    expect(buffer.add(5), "Fifth value should fit after wraparound");

    expectReadValue(buffer, 3, "Wrapped read one");
    expectReadValue(buffer, 4, "Wrapped read two");
    expectReadValue(buffer, 5, "Wrapped read three");
    expect(!buffer.read().has_value(), "Buffer should be empty after wrapped reads");
  }

  void testOverflowDoesNotOverwriteQueuedItems() {
    beginTest("Ring buffer overflow leaves queued items intact");

    RingBuffer<int, 3> buffer;

    expect(buffer.add(100), "First value should be added");
    expect(buffer.add(200), "Second value should be added");
    expect(buffer.add(300), "Third value should be added");
    expect(!buffer.add(400), "Overflow write should be rejected");

    expectReadValue(buffer, 100, "Post-overflow read one");
    expectReadValue(buffer, 200, "Post-overflow read two");
    expectReadValue(buffer, 300, "Post-overflow read three");
    expect(!buffer.read().has_value(), "Overflow should not add an extra item");
  }
};

static RingBufferTest ringBufferTest;

} // namespace anthem
