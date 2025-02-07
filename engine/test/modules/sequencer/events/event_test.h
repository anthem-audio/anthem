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
    testAnthemSequenceTimeOperators();
    testAnthemSequenceEventOperators();
  }

private:
  void testAnthemSequenceTimeOperators() {
    beginTest ("AnthemSequenceTime Operators");

    AnthemSequenceTime time1{ .ticks = 10, .fraction = 0.5 };
    AnthemSequenceTime time2{ .ticks = 20, .fraction = 0.0 };
    AnthemSequenceTime time3{ .ticks = 10, .fraction = 0.5 };
    AnthemSequenceTime time4{ .ticks = 5, .fraction = 0.8 };
    AnthemSequenceTime time5{ .ticks = 10, .fraction = 0.8 };

    // operator=
    AnthemSequenceTime timeCopy = time2;
    expectEquals (timeCopy.ticks, time2.ticks, "operator=: ticks");
    expectEquals (timeCopy.fraction, time2.fraction, "operator=: fraction");

    // operator<
    expect (time1 < time2, "operator<: time1 < time2");
    expect (!(time2 < time1), "operator<: !(time2 < time1)");
    expect (!(time1 < time3), "operator<: !(time1 < time3) - equal");
    expect (time4 < time1, "operator<: time4 < time1 - smaller ticks");
    expect (time1 < time5, "operator<: time1 < time5 - equal ticks, smaller fraction");

    // operator>
    expect (time2 > time1, "operator>: time2 > time1");
    expect (!(time1 > time2), "operator>: !(time1 > time2)");
    expect (!(time1 > time3), "operator>: !(time1 > time3) - equal");
    expect (!(time4 > time1), "operator>: !(time4 > time1) - smaller ticks");
    expect (!(time1 > time5), "operator>: !(time1 > time5) - equal ticks, smaller fraction");
    expect (time5 > time1, "operator>: time5 > time1 - equal ticks, larger fraction");

    // operator<=
    expect (time1 <= time2, "operator<=: time1 <= time2");
    expect (!(time2 <= time1), "operator<=: !(time2 <= time1)");
    expect (time1 <= time3, "operator<=: time1 <= time3 - equal");
    expect (time4 <= time1, "operator<=: time4 <= time1 - smaller ticks");
    expect (time1 <= time5, "operator<=: time1 <= time5 - equal ticks, smaller fraction");
    expect (time1 <= time1, "operator<=: time1 <= time1 - self");

    // operator>=
    expect (time2 >= time1, "operator>=: time2 >= time1");
    expect (!(time1 >= time2), "operator>=: !(time1 >= time2)");
    expect (time1 >= time3, "operator>=: time1 >= time3 - equal");
    expect (!(time4 >= time1), "operator>=: !(time4 >= time1) - smaller ticks");
    expect (!(time1 >= time5), "operator>=: !(time1 >= time5) - equal ticks, smaller fraction");
    expect (time2 >= time2, "operator>=: time2 >= time2 - self");
  }

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
