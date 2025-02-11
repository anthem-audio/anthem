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

#include <cmath>

#include "modules/sequencer/compiler/sequence_compiler.h"

#include "modules/core/anthem.h"
#include "modules/core/project.h"
#include "generated/lib/model/pattern/pattern.h"

#include "test/test_constants.h"

#include <rfl.hpp>
#include <rfl/json.hpp>

class SequenceCompilerTest : public juce::UnitTest {
  bool isSorted(const std::vector<AnthemSequenceEvent>& events) {
    for (int i = 0; i < events.size(); i++) {
      if (i > 0) {
        if (events.at(i).time.ticks < events.at(i - 1).time.ticks ||
            (events.at(i).time.ticks == events.at(i - 1).time.ticks &&
            events.at(i).time.fraction < events.at(i - 1).time.fraction)) {
          return false;
        }
      }
    }

    return true;
  }

public:
  SequenceCompilerTest() : juce::UnitTest("SequenceCompilerTest", "Anthem") {}

  void runTest() override {
    testEventSorting();
    testClampTimeToRange();
    testClampTimeToRangeFractional();
    testClampStartAndEndToRange();
    testPatternNoteCompiler();
  }

  void testEventSorting() {
    beginTest("Event sorting");
    auto eventList = std::vector<AnthemSequenceEvent>();
    AnthemSequenceCompiler::sortEventList(eventList);

    eventList.push_back(AnthemSequenceEvent {
      .time = AnthemSequenceTime {
        .ticks = 0,
        .fraction = 0.
      },
      .event = AnthemEvent {
        .type = AnthemEventType::NoteOn,
        .noteOn = AnthemNoteOnEvent()
      }
    });

    eventList.push_back(AnthemSequenceEvent {
      .time = AnthemSequenceTime {
        .ticks = 1,
        .fraction = 0.5
      },
      .event = AnthemEvent {
        .type = AnthemEventType::NoteOn,
        .noteOn = AnthemNoteOnEvent()
      }
    });

    eventList.push_back(AnthemSequenceEvent {
      .time = AnthemSequenceTime {
        .ticks = 1,
        .fraction = 0.
      },
      .event = AnthemEvent {
        .type = AnthemEventType::NoteOn,
        .noteOn = AnthemNoteOnEvent()
      }
    });

    AnthemSequenceCompiler::sortEventList(eventList);

    expect(eventList.size() == 3, "There are three events");
    for (int i = 0; i < eventList.size(); i++) {
      if (i > 0) {
        expect(isSorted(eventList), "The events are sorted");
      }
    }
  }

  void testClampTimeToRange() {
    beginTest ("ClampTimeToRange");

    AnthemSequenceTime time{ .ticks = 10, .fraction = 0.5 };
    AnthemSequenceTime rangeStart{ .ticks = 20, .fraction = 0.0 };
    AnthemSequenceTime rangeEnd{ .ticks = 30, .fraction = 0.0 };
    auto range = std::make_tuple(rangeStart, rangeEnd);

    // Time before range
    expect (AnthemSequenceCompiler::clampTimeToRange(time, range).ticks == 20, "clampTimeToRange: before range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(time, range).fraction == 0.0, "clampTimeToRange: before range - fraction");

    // Time after range
    AnthemSequenceTime timeAfter{ .ticks = 40, .fraction = 0.5 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAfter, range).ticks == 30, "clampTimeToRange: after range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAfter, range).fraction == 0.0, "clampTimeToRange: after range - fraction");

    // Time in range
    AnthemSequenceTime timeInRange{ .ticks = 25, .fraction = 0.5 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeInRange, range).ticks == 25, "clampTimeToRange: in range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeInRange, range).fraction == 0.5, "clampTimeToRange: in range - fraction");

    // Time equal to range start
    AnthemSequenceTime timeAtStart{ .ticks = 20, .fraction = 0.0 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAtStart, range).ticks == 20, "clampTimeToRange: at start - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAtStart, range).fraction == 0.0, "clampTimeToRange: at start - fraction");

    // Time equal to range end
    AnthemSequenceTime timeAtEnd{ .ticks = 30, .fraction = 0.0 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAtEnd, range).ticks == 30, "clampTimeToRange: at end - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAtEnd, range).fraction == 0.0, "clampTimeToRange: at end - fraction");

    // Range starting at 0
    AnthemSequenceTime rangeStartZero{ .ticks = 0, .fraction = 0.0 };
    auto rangeZeroStart = std::make_tuple(rangeStartZero, rangeEnd);
    expect (AnthemSequenceCompiler::clampTimeToRange(time, rangeZeroStart).ticks == 10, "clampTimeToRange: range start zero - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(time, rangeZeroStart).fraction == 0.5, "clampTimeToRange: range start zero - fraction");

    // Range ending at 0 with 0 size
    AnthemSequenceTime rangeEndZero{ .ticks = 0, .fraction = 0.0 };
    auto rangeZeroEnd = std::make_tuple(rangeStartZero, rangeEndZero);
    expect (AnthemSequenceCompiler::clampTimeToRange(time, rangeZeroEnd).ticks == 0, "clampTimeToRange: range end zero - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(time, rangeZeroEnd).fraction == 0.0, "clampTimeToRange: range end zero - fraction");
  }

  void testClampTimeToRangeFractional() {
    beginTest ("ClampTimeToRange - fractional");

    AnthemSequenceTime time{ .ticks = 10, .fraction = 0.5 };
    AnthemSequenceTime rangeStart{ .ticks = 20, .fraction = 0.1 };
    AnthemSequenceTime rangeEnd{ .ticks = 30, .fraction = 0.9 };

    auto range = std::make_tuple(rangeStart, rangeEnd);

    // Time before range
    expect (AnthemSequenceCompiler::clampTimeToRange(time, range).ticks == 20, "clampTimeToRange: before range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(time, range).fraction == 0.1, "clampTimeToRange: before range - fraction");

    // Time after range
    AnthemSequenceTime timeAfter{ .ticks = 40, .fraction = 0.5 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAfter, range).ticks == 30, "clampTimeToRange: after range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeAfter, range).fraction == 0.9, "clampTimeToRange: after range - fraction");

    // Time in range
    AnthemSequenceTime timeInRange{ .ticks = 25, .fraction = 0.5 };
    expect (AnthemSequenceCompiler::clampTimeToRange(timeInRange, range).ticks == 25, "clampTimeToRange: in range - ticks");
    expect (AnthemSequenceCompiler::clampTimeToRange(timeInRange, range).fraction == 0.5, "clampTimeToRange: in range - fraction");
  }

  void testClampStartAndEndToRange() {
    beginTest("ClampStartAndEndToRange");

    AnthemSequenceTime timeStart{.ticks = 10, .fraction = 0.5};
    AnthemSequenceTime timeEnd{.ticks = 35, .fraction = 0.0};
    auto timeRange = std::make_tuple(timeStart, timeEnd);

    AnthemSequenceTime rangeStart{.ticks = 20, .fraction = 0.0};
    AnthemSequenceTime rangeEnd{.ticks = 30, .fraction = 0.0};
    auto range = std::make_tuple(rangeStart, rangeEnd);

    std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> clampedRange;

    // Test case 1: Start and end before the range, nullopt returned
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 5, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 10, .fraction = 0.0}, range);
    expect(!clampedRange.has_value(), "Test Case 1 Failed: Should return nullopt");

    // Test case 2: Start or end exactly equals range bounds
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 20, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 30, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 2 Failed: Should return a value");
    expect(clampedRange.value() == range, "Test Case 2 Failed: Should not clamp");

    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 15, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 20, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 2 (branch 2) Failed: Should return a value");
    expect(std::get<0>(clampedRange.value()).ticks == 20, "Test Case 2 (branch 2) Failed: Start should be clamped");
    expect(std::get<1>(clampedRange.value()).ticks == 20, "Test Case 2 (branch 2) Failed: End should be clamped");

    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 30, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 35, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 2 (branch 3) Failed: Should return a value");
    expect(std::get<0>(clampedRange.value()).ticks == 30, "Test Case 2 (branch 3) Failed: Start should be clamped");
    expect(std::get<1>(clampedRange.value()).ticks == 30, "Test Case 2 (branch 3) Failed: End should be clamped");

    // Test case 3: Start and/or end are clamped
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 15, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 35, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 3 Failed: Should return a value");
    expect(std::get<0>(clampedRange.value()).ticks == 20, "Test Case 3 Failed: Start should be clamped");
    expect(std::get<1>(clampedRange.value()).ticks == 30, "Test Case 3 Failed: End should be clamped");

    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 25, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 35, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 3 (branch 2) Failed: Should return a value");
    expect(std::get<1>(clampedRange.value()).ticks == 30, "Test Case 3 (branch 2) Failed: End should be clamped");

    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 15, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 25, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 3 (branch 3) Failed: Should return a value");
    expect(std::get<0>(clampedRange.value()).ticks == 20, "Test Case 3 (branch 3) Failed: Start should be clamped");

    // Test case 4: Neither start or end are clamped
    clampedRange = AnthemSequenceCompiler::clampStartAndEndToRange(
        AnthemSequenceTime{.ticks = 25, .fraction = 0.0},
        AnthemSequenceTime{.ticks = 26, .fraction = 0.0}, range);
    expect(clampedRange.has_value(), "Test Case 4 Failed: Should return a value");
    expect(clampedRange.value() == std::make_tuple(AnthemSequenceTime{.ticks = 25, .fraction = 0.0}, AnthemSequenceTime{.ticks = 26, .fraction = 0.0}), "Test Case 4 Failed: Should not clamp");
  }

  void testPatternNoteCompiler() {
    beginTest("Test compiling pattern notes for a channel");

    rfl::Result<std::shared_ptr<Project>> projectResult = rfl::json::read<std::shared_ptr<Project>>(TestConstants::getEmptyProjectJson());

    expect(!projectResult.error().has_value(), "Project is valid");

    auto& anthem = Anthem::getInstance();
    anthem.project = std::move(projectResult.value());

    rfl::Result<std::shared_ptr<PatternModel>> patternResult = rfl::json::read<std::shared_ptr<PatternModel>>(
      TestConstants::getEmptyPatternJson("patternId1")
    );

    expect(!patternResult.error().has_value(), "Pattern is valid");

    anthem.project->sequence()->patterns()->insert_or_assign("patternId1", patternResult.value());

    auto& pattern = anthem.project->sequence()->patterns()->at("patternId1");

    // notes() is a map of channel ID to a vector of notes
    pattern->notes()->insert_or_assign(
      "channelId1",
      std::make_shared<AnthemModelVector<std::shared_ptr<NoteModel>>>()
    );

    pattern->notes()->at("channelId1")->emplace_back(std::make_shared<NoteModel>(NoteModelImpl {
      .id = "noteId1",
      .key = 60,
      .velocity = 0.5,
      .length = 10,
      .offset = 10,
      .pan = 0.0
    }));

    // We're mimicing the behavior of the generated model sync code here, so we
    // need to initialize models that we create.
    //
    // This is a cheap way to make sure that the whole model is initialized,
    // since this is recursive. However, doing this repeatedly in the test
    // meaans we are going to double-initialize the model. Maybe this is fine,
    // but it's not what would happen in the application, so if something needs
    // to rely on only initializing once, then we'll need to change this.
    anthem.project->initialize(
      anthem.project,
      nullptr
    );

    std::vector<AnthemSequenceEvent> events;

    // Case 1: One note, no range or offset
    AnthemSequenceCompiler::getChannelNoteEventsForPattern(
      "channelId1",
      "patternId1",
      std::nullopt,
      std::nullopt,
      events
    );

    expect(events.size() == 2, "Case 1: There are two events");

    expect(events.at(0).time.ticks == 10, "Case 1: Note on event ticks");
    expect(events.at(0).event.type == AnthemEventType::NoteOn, "Case 1: Note on event type");
    expect(events.at(0).event.noteOn.pitch == 60, "Case 1: Note on event key");
    expect(fabs(events.at(0).event.noteOn.velocity - 0.5) < 0.001, "Case 1: Note on event velocity");

    expect(events.at(1).time.ticks == 20, "Case 1: Note off event ticks");
    expect(events.at(1).event.type == AnthemEventType::NoteOff, "Case 1: Note off event type");
    expect(events.at(1).event.noteOff.pitch == 60, "Case 1: Note off event key");
    expect(fabs(events.at(1).event.noteOff.velocity - 0.0) < 0.001, "Case 1: Note off event velocity");

    events.clear();

    // Case 2: One note, with offset
    AnthemSequenceCompiler::getChannelNoteEventsForPattern(
      "channelId1",
      "patternId1",
      std::nullopt,
      AnthemSequenceTime { .ticks = 5, .fraction = 0.5 },
      events
    );

    expect(events.size() == 2, "Case 2: There are two events");

    expect(events.at(0).time.ticks == 15, "Case 2: Note on event ticks");
    expect(fabs(events.at(0).time.fraction - 0.5) < 0.001, "Case 2: Note on event fraction");
    expect(events.at(0).event.type == AnthemEventType::NoteOn, "Case 2: Note on event type");

    expect(events.at(1).time.ticks == 25, "Case 2: Note off event ticks");
    expect(fabs(events.at(1).time.fraction - 0.5) < 0.001, "Case 2: Note off event fraction");
    expect(events.at(1).event.type == AnthemEventType::NoteOff, "Case 2: Note off event type");

    events.clear();

    // Case 3: One note, with range
    AnthemSequenceCompiler::getChannelNoteEventsForPattern(
      "channelId1",
      "patternId1",
      std::make_tuple(
        AnthemSequenceTime { .ticks = 5, .fraction = 0.5 },
        AnthemSequenceTime { .ticks = 15, .fraction = 0.5 }
      ),
      std::nullopt,
      events
    );

    expect(events.size() == 2, "Case 3: One note, with range");

    // When we clamp to a range, we output as if the start of the range is the
    // start of the sequence. This is for outputting clips into the event list
    // of an arrangement. We can offset the output using the offset parameter if
    // that clip is not at the start of its containing sequence.
    expect(events.at(0).time.ticks == 4, "Case 3: Note on event ticks");
    expect(fabs(events.at(0).time.fraction - 0.5) < 0.001, "Case 3: Note on event fraction");
    expect(events.at(0).event.type == AnthemEventType::NoteOn, "Case 3: Note on event type");

    // The note starts at 10.0, and we cut it off at 15.5, so it needs to be 5.5
    // ticks long.
    expect(events.at(1).time.ticks == 10, "Case 3: Note off event ticks");
    expect(fabs(events.at(1).time.fraction - 0.0) < 0.001, "Case 3: Note off event fraction");
    expect(events.at(1).event.type == AnthemEventType::NoteOff, "Case 3: Note off event type");

    events.clear();

    // Case 4: One note, with range and offset
    AnthemSequenceCompiler::getChannelNoteEventsForPattern(
      "channelId1",
      "patternId1",
      std::make_tuple(
        AnthemSequenceTime { .ticks = 5, .fraction = 0.5 },
        AnthemSequenceTime { .ticks = 15, .fraction = 0.5 }
      ),
      AnthemSequenceTime { .ticks = 5, .fraction = 0.5 },
      events
    );

    expect(events.size() == 2, "Case 3: One note, with range");

    // Same as the above, except shifted by 5.5
    expect(events.at(0).time.ticks == 10, "Case 3: Note on event ticks");
    expect(fabs(events.at(0).time.fraction - 0.0) < 0.001, "Case 3: Note on event fraction");
    expect(events.at(0).event.type == AnthemEventType::NoteOn, "Case 3: Note on event type");

    expect(events.at(1).time.ticks == 15, "Case 3: Note off event ticks");
    expect(fabs(events.at(1).time.fraction - 0.5) < 0.001, "Case 3: Note off event fraction");
    expect(events.at(1).event.type == AnthemEventType::NoteOff, "Case 3: Note off event type");

    events.clear();

    // Case 5: Clip bounds out of range
    AnthemSequenceCompiler::getChannelNoteEventsForPattern(
      "channelId1",
      "patternId1",
      std::make_tuple(
        AnthemSequenceTime { .ticks = 50, .fraction = 0.5 },
        AnthemSequenceTime { .ticks = 60, .fraction = 0.5 }
      ),
      std::nullopt,
      events
    );

    expect(events.size() == 0, "Case 5: No events");
  }
};

static SequenceCompilerTest sequenceCompilerTest;
