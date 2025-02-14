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

#include "modules/sequencer/time.h"
#include <juce_core/juce_core.h>

class TimeTest : public juce::UnitTest {
public:
  TimeTest() : juce::UnitTest ("TimeTest", "Anthem") {}

  void runTest() override {
    testAnthemSequenceTimeOperators();
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

		expect (time1 + time2 == AnthemSequenceTime { .ticks = 30, .fraction = 0.5 }, "operator+: time1 + time2");
		expect ((time1 + time5).ticks == 21, "operator+: time1 + time5 ticks");
		expect (std::abs((time1 + time5).fraction - 0.3) < 0.0001, "operator+: time1 + time5 fraction");
		expect ((time2 - time1).ticks == 9, "operator-: time1 - time2 ticks");
		expect (std::abs((time2 - time1).fraction - 0.5) < 0.0001, "operator-: time1 - time2 fraction");
  }
};

static TimeTest TimeTest;
