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
  EventTest() : juce::UnitTest ("EventTest", "Anthem") {}

  void runTest() override {
    testAnthemSequenceEventOperators();
  }

private:
  void testAnthemSequenceEventOperators() {
    beginTest ("AnthemSequenceEvent Operators");

    AnthemSequenceEvent event1{ .time = { .ticks = 10, .fraction = 0.5 }, .event = { .type = AnthemEventType::NoteOn } };
    AnthemSequenceEvent event2{ .time = { .ticks = 20, .fraction = 0.0 }, .event = { .type = AnthemEventType::NoteOff } };
    AnthemSequenceEvent event3{ .time = { .ticks = 10, .fraction = 0.5 }, .event = { .type = AnthemEventType::NoteOn } };
    AnthemSequenceEvent event4{ .time = { .ticks = 5, .fraction = 0.8 }, .event = { .type = AnthemEventType::NoteOff } };
    AnthemSequenceEvent event5{ .time = { .ticks = 10, .fraction = 0.8 }, .event = { .type = AnthemEventType::NoteOn } };

    // operator=
    AnthemSequenceEvent eventCopy = event2;
    expectEquals (eventCopy.time.ticks, event2.time.ticks, "operator= event: ticks");
    expectEquals (eventCopy.time.fraction, event2.time.fraction, "operator= event: fraction");
    expectEquals ((int)eventCopy.event.type, (int)event2.event.type, "operator= event: type");

    // operator<
    expect (event1 < event2, "operator< event: event1 < event2");
    expect (!(event2 < event1), "operator< event: !(event2 < event1)");
    expect (!(event1 < event3), "operator< event: !(event1 < event3) - equal");
    expect (event4 < event1, "operator< event: event4 < event1 - smaller ticks");
    expect (event1 < event5, "operator< event: event1 < event5 - equal ticks, smaller fraction");

    // operator>
    expect (event2 > event1, "operator> event: event2 > event1");
    expect (!(event1 > event2), "operator> event: !(event1 > event2)");
    expect (!(event1 > event3), "operator> event: !(event1 > event3) - equal");
    expect (!(event4 > event1), "operator> event: !(event4 > event1) - smaller ticks");
    expect (!(event1 > event5), "operator> event: !(event1 > event5) - equal ticks, smaller fraction");
    expect (event5 > event1, "operator> event: event5 > event1 - equal ticks, larger fraction");

    // operator<=
    expect (event1 <= event2, "operator<= event: event1 <= event2");
    expect (!(event2 <= event1), "operator<= event: !(event2 <= event1)");
    expect (event1 <= event3, "operator<= event: event1 <= event3 - equal");
    expect (event4 <= event1, "operator<= event: event4 <= event1 - smaller ticks");
    expect (event1 <= event5, "operator<= event: event1 <= event5 - equal ticks, smaller fraction");
    expect (event1 <= event1, "operator<= event: event1 <= event1 - self");

    // operator>=
    expect (event2 >= event1, "operator>= event: event2 >= event1");
    expect (!(event1 >= event2), "operator>= event: !(event1 >= event2)");
    expect (event1 >= event3, "operator>= event: event1 >= event3 - equal");
    expect (!(event4 >= event1), "operator>= event: !(event4 >= event1) - smaller ticks");
    expect (!(event1 >= event5), "operator>= event: !(event1 >= event5) - equal ticks, smaller fraction");
    expect (event2 >= event2, "operator>= event: event2 >= event2 - self");
  }
};

static EventTest eventTest;
