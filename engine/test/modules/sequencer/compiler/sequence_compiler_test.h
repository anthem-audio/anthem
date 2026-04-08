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

#include "modules/sequencer/compiler/sequence_compiler.h"

#include <cmath>

class SequenceCompilerTest : public juce::UnitTest {
  static bool nearlyEqual(double a, double b) {
    return std::fabs(a - b) < 0.0001;
  }

  bool isSorted(const std::vector<AnthemSequenceEvent>& events) {
    for (size_t i = 1; i < events.size(); i++) {
      if (events.at(i - 1).offset > events.at(i).offset) {
        return false;
      }

      if (nearlyEqual(events.at(i - 1).offset, events.at(i).offset) &&
          events.at(i - 1).event.type > events.at(i).event.type) {
        return false;
      }
    }

    return true;
  }
public:
  SequenceCompilerTest() : juce::UnitTest("SequenceCompilerTest", "Anthem") {}

  void runTest() override {
    testEventSorting();
    testClampTimeToRange();
    testClampStartAndEndToRange();
  }

  void testEventSorting() {
    beginTest("Event sorting");

    auto eventList = std::vector<AnthemSequenceEvent>();
    AnthemSequenceCompiler::sortEventList(eventList);

    eventList.push_back(
        AnthemSequenceEvent{.offset = 1.0, .event = AnthemEvent(AnthemNoteOnEvent())});

    eventList.push_back(
        AnthemSequenceEvent{.offset = 1.0, .event = AnthemEvent(AnthemNoteOffEvent())});

    eventList.push_back(
        AnthemSequenceEvent{.offset = 0.5, .event = AnthemEvent(AnthemNoteOnEvent())});

    AnthemSequenceCompiler::sortEventList(eventList);

    expect(eventList.size() == 3, "There are three events");
    expect(isSorted(eventList), "The events are sorted");
    expect(nearlyEqual(eventList.at(0).offset, 0.5), "First event offset is 0.5");
    expect(eventList.at(1).event.type == AnthemEventType::NoteOff,
        "NoteOff is ordered before NoteOn at equal offset");
    expect(eventList.at(2).event.type == AnthemEventType::NoteOn,
        "NoteOn is ordered after NoteOff at equal offset");
  }

  void testClampTimeToRange() {
    beginTest("ClampTimeToRange");

    auto range = std::make_tuple(20.0, 30.0);

    expect(nearlyEqual(AnthemSequenceCompiler::clampTimeToRange(10.0, range), 20.0),
        "Time below range clamps to start");
    expect(nearlyEqual(AnthemSequenceCompiler::clampTimeToRange(40.0, range), 30.0),
        "Time above range clamps to end");
    expect(nearlyEqual(AnthemSequenceCompiler::clampTimeToRange(25.5, range), 25.5),
        "Time in range is unchanged");
    expect(nearlyEqual(AnthemSequenceCompiler::clampTimeToRange(20.0, range), 20.0),
        "Range start is unchanged");
    expect(nearlyEqual(AnthemSequenceCompiler::clampTimeToRange(30.0, range), 30.0),
        "Range end is unchanged");
  }

  void testClampStartAndEndToRange() {
    beginTest("ClampStartAndEndToRange");

    auto range = std::make_optional(std::make_tuple(20.0, 30.0));

    std::optional<std::tuple<double, double>> clampedRange;

    // Entirely before range -> no output
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(5.0, 10.0, range);
    expect(!clampedRange.has_value(), "Times before range should return nullopt");

    // Entirely after range -> no output
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(30.0, 35.0, range);
    expect(!clampedRange.has_value(), "Times after range should return nullopt");

    // Exact bounds -> unchanged
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(20.0, 30.0, range);
    expect(clampedRange.has_value(), "Range bounds should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 20.0), "Start matches range start");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 30.0), "End matches range end");

    // Overlap left edge
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(15.0, 25.0, range);
    expect(clampedRange.has_value(), "Overlap left should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 20.0), "Start clamps to range start");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 25.0), "End remains in range");

    // Overlap right edge
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(25.0, 35.0, range);
    expect(clampedRange.has_value(), "Overlap right should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 25.0), "Start remains in range");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 30.0), "End clamps to range end");

    // No range -> unchanged
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(25.0, 35.0, std::nullopt);
    expect(clampedRange.has_value(), "No range should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 25.0), "Start unchanged without range");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 35.0), "End unchanged without range");
  }
};

static SequenceCompilerTest sequenceCompilerTest;
