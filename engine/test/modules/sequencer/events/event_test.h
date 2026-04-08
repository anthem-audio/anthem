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

#include "modules/sequencer/events/event.h"

#include <juce_core/juce_core.h>

class EventTest : public juce::UnitTest {
public:
  EventTest() : juce::UnitTest("EventTest", "Anthem") {}

  void runTest() override {
    beginTest("AnthemSequenceEvent comparison operators");

    AnthemSequenceEvent event1{.offset = 10.5, .event = AnthemEvent(AnthemNoteOnEvent())};
    AnthemSequenceEvent event2{.offset = 20.0, .event = AnthemEvent(AnthemNoteOffEvent())};
    AnthemSequenceEvent event3{.offset = 10.5, .event = AnthemEvent(AnthemNoteOnEvent())};
    AnthemSequenceEvent event4{.offset = 5.8, .event = AnthemEvent(AnthemNoteOffEvent())};
    AnthemSequenceEvent event5{.offset = 10.8, .event = AnthemEvent(AnthemNoteOnEvent())};

    AnthemSequenceEvent eventCopy = event2;
    expectEquals(eventCopy.offset, event2.offset, "operator=: offset");
    expectEquals(static_cast<int>(eventCopy.event.type),
        static_cast<int>(event2.event.type),
        "operator=: type");

    expect(event1 < event2, "operator<: event1 < event2");
    expect(!(event2 < event1), "operator<: !(event2 < event1)");
    expect(!(event1 < event3), "operator<: equal offsets");
    expect(event4 < event1, "operator<: smaller offset");
    expect(event1 < event5, "operator<: equal major order, smaller offset");

    expect(event2 > event1, "operator>: event2 > event1");
    expect(!(event1 > event2), "operator>: !(event1 > event2)");
    expect(!(event1 > event3), "operator>: equal offsets");
    expect(!(event4 > event1), "operator>: smaller offset");
    expect(event5 > event1, "operator>: larger offset");

    expect(event1 <= event2, "operator<=: event1 <= event2");
    expect(!(event2 <= event1), "operator<=: !(event2 <= event1)");
    expect(event1 <= event3, "operator<=: equal offsets");
    expect(event4 <= event1, "operator<=: smaller offset");
    expect(event1 <= event1, "operator<=: self");

    expect(event2 >= event1, "operator>=: event2 >= event1");
    expect(!(event1 >= event2), "operator>=: !(event1 >= event2)");
    expect(event1 >= event3, "operator>=: equal offsets");
    expect(!(event4 >= event1), "operator>=: smaller offset");
    expect(event2 >= event2, "operator>=: self");
  }
};

static EventTest eventTest;
