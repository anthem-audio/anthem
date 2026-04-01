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

#include "modules/processing_graph/processor/anthem_event_buffer.h"

#include <juce_core/juce_core.h>

class AnthemEventBufferTest : public juce::UnitTest {
public:
  AnthemEventBufferTest() : juce::UnitTest("AnthemEventBufferTest", "Anthem") {}

  void runTest() override {
    {
      beginTest("Event buffer grows and preserves existing events");

      AnthemEventBuffer buffer(1);

      AnthemLiveEvent first{};
      first.sampleOffset = 1.0;
      first.event.type = AnthemEventType::NoteOn;

      AnthemLiveEvent second{};
      second.sampleOffset = 2.0;
      second.event.type = AnthemEventType::NoteOff;

      expect(buffer.addEvent(first), "First event should be added.");
      expect(buffer.addEvent(second), "Second event should trigger growth and be added.");

      expectEquals(
          static_cast<int>(buffer.getNumEvents()), 2, "Buffer should contain both events.");
      expectEquals(static_cast<int>(buffer.getSize()), 2, "Buffer capacity should double.");
      expectEquals(static_cast<int>(buffer.getTimesGrown()), 1, "Buffer should have grown once.");
      expectEquals(
          buffer.getEvent(0).sampleOffset, first.sampleOffset, "First event should be preserved.");
      expectEquals(
          buffer.getEvent(1).sampleOffset, second.sampleOffset, "Second event should be written.");
    }

    {
      beginTest("Clear preserves grown capacity and resets per-block overflow state");

      AnthemEventBuffer buffer(1);

      AnthemLiveEvent event{};
      event.sampleOffset = 0.0;
      event.event.type = AnthemEventType::NoteOn;

      expect(buffer.addEvent(event), "First event should be added.");
      expect(buffer.addEvent(event), "Second event should grow the buffer.");

      auto capacityAfterGrowth = buffer.getSize();

      buffer.clear();

      expectEquals(
          static_cast<int>(buffer.getNumEvents()), 0, "Clear should reset the event count.");
      expectEquals(static_cast<int>(buffer.getSize()),
                   static_cast<int>(capacityAfterGrowth),
                   "Clear should preserve capacity.");
      expect(!buffer.didOverflowThisBlock(), "Clear should reset the overflow flag.");
      expectEquals(static_cast<int>(buffer.getDroppedEventsThisBlock()),
                   0,
                   "Clear should reset dropped-event diagnostics.");
    }

    {
      beginTest("Event buffer enforces the hard maximum size");

      AnthemEventBuffer buffer(MAX_EVENT_BUFFER_SIZE);

      AnthemLiveEvent event{};
      event.sampleOffset = 0.0;
      event.event.type = AnthemEventType::NoteOn;

      for (int i = 0; i < MAX_EVENT_BUFFER_SIZE; i++) {
        expect(buffer.addEvent(event), "Events up to the hard cap should be accepted.");
      }

      expect(!buffer.addEvent(event), "Events beyond the hard cap should be dropped.");
      expect(buffer.didOverflowThisBlock(),
             "Dropping an event should mark the buffer as overflowed.");
      expectEquals(static_cast<int>(buffer.getDroppedEventsThisBlock()),
                   1,
                   "Dropped event count should increment.");
      expectEquals(static_cast<int>(buffer.getNumEvents()),
                   MAX_EVENT_BUFFER_SIZE,
                   "Buffer should not exceed the hard cap.");
      expectEquals(static_cast<int>(buffer.getHighWaterMark()),
                   MAX_EVENT_BUFFER_SIZE,
                   "High-water mark should reflect the cap.");
    }
  }
};

static AnthemEventBufferTest anthemEventBufferTest;
