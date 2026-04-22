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

#include "modules/util/note_tracker.h"

#include <array>
#include <juce_core/juce_core.h>

namespace anthem {

class NoteTrackerTest : public juce::UnitTest {
  static constexpr int64_t firstInputId = 101;
  static constexpr int64_t secondInputId = 102;
  static constexpr int64_t thirdInputId = 103;
  static constexpr LiveNoteId firstLiveId = 1001;
  static constexpr LiveNoteId secondLiveId = 1002;
  static constexpr LiveNoteId thirdLiveId = 1003;

  void expectTrackedNote(const TrackedNote& note,
      int64_t expectedInputId,
      LiveNoteId expectedLiveId,
      int16_t expectedPitch,
      int16_t expectedChannel,
      const juce::String& context) {
    expectEquals(note.inputId, expectedInputId, context + " input ID");
    expectEquals(note.liveId, expectedLiveId, context + " live ID");
    expectEquals(note.pitch, expectedPitch, context + " pitch");
    expectEquals(note.channel, expectedChannel, context + " channel");
  }
public:
  NoteTrackerTest() : juce::UnitTest("NoteTrackerTest", "Anthem") {}

  void runTest() override {
    testAddAndTakeByInputId();
    testTakeAllDrainsTracker();
    testOverflowAccountingAndHighWaterMark();
  }

  void testAddAndTakeByInputId() {
    beginTest("Note tracker adds notes and removes them by input ID");

    NoteTracker<4> tracker;

    expect(tracker.rt_add(firstInputId, firstLiveId, 60, 1), "First note should be tracked");
    expect(tracker.rt_add(secondInputId, secondLiveId, 64, 2), "Second note should be tracked");
    expect(tracker.rt_add(thirdInputId, thirdLiveId, 67, 3), "Third note should be tracked");
    expectEquals(static_cast<int>(tracker.rt_getSize()), 3, "Three notes should be active");

    auto removedSecond = tracker.rt_takeByInputId(secondInputId);
    expect(removedSecond.has_value(), "Existing input ID should be removable");
    if (removedSecond.has_value()) {
      expectTrackedNote(
          removedSecond.value(), secondInputId, secondLiveId, 64, 2, "Removed second note");
    }

    expectEquals(static_cast<int>(tracker.rt_getSize()),
        2,
        "Removing one note should decrement the active size");

    auto removedMissing = tracker.rt_takeByInputId(999);
    expect(!removedMissing.has_value(), "Missing input ID should return nullopt");

    auto removedFirst = tracker.rt_takeByInputId(firstInputId);
    expect(removedFirst.has_value(), "First note should still be removable after swap-remove");
    if (removedFirst.has_value()) {
      expectTrackedNote(
          removedFirst.value(), firstInputId, firstLiveId, 60, 1, "Removed first note");
    }

    auto removedThird = tracker.rt_takeByInputId(thirdInputId);
    expect(removedThird.has_value(), "Third note should still be removable");
    if (removedThird.has_value()) {
      expectTrackedNote(
          removedThird.value(), thirdInputId, thirdLiveId, 67, 3, "Removed third note");
    }

    expectEquals(
        static_cast<int>(tracker.rt_getSize()), 0, "Removing every note should empty the tracker");
  }

  void testTakeAllDrainsTracker() {
    beginTest("Note tracker take-all drains all tracked notes");

    NoteTracker<4> tracker;

    expect(tracker.rt_add(firstInputId, firstLiveId, 60, 1), "First note should be tracked");
    expect(tracker.rt_add(secondInputId, secondLiveId, 64, 2), "Second note should be tracked");
    expect(tracker.rt_add(thirdInputId, thirdLiveId, 67, 3), "Third note should be tracked");

    std::array<bool, 3> sawInputId{false, false, false};
    int callbackCount = 0;

    tracker.rt_takeAll([&](const TrackedNote& note) {
      callbackCount++;

      if (note.inputId == firstInputId) {
        sawInputId[0] = true;
        expectTrackedNote(note, firstInputId, firstLiveId, 60, 1, "Take-all first note");
      } else if (note.inputId == secondInputId) {
        sawInputId[1] = true;
        expectTrackedNote(note, secondInputId, secondLiveId, 64, 2, "Take-all second note");
      } else if (note.inputId == thirdInputId) {
        sawInputId[2] = true;
        expectTrackedNote(note, thirdInputId, thirdLiveId, 67, 3, "Take-all third note");
      } else {
        expect(false, "Take-all should only return known tracked notes");
      }
    });

    expectEquals(callbackCount, 3, "Take-all should invoke the callback once per tracked note");
    expect(sawInputId[0] && sawInputId[1] && sawInputId[2],
        "Take-all should yield every tracked note");
    expectEquals(static_cast<int>(tracker.rt_getSize()), 0, "Take-all should drain the tracker");
  }

  void testOverflowAccountingAndHighWaterMark() {
    beginTest("Note tracker reports overflow and keeps a stable high-water mark");

    NoteTracker<2> tracker;

    expect(tracker.rt_add(firstInputId, firstLiveId, 60, 1), "First note should fit");
    expect(tracker.rt_add(secondInputId, secondLiveId, 64, 2), "Second note should fit");
    expect(!tracker.rt_add(thirdInputId, thirdLiveId, 67, 3), "Third note should overflow");

    expectEquals(static_cast<int>(tracker.rt_getSize()), 2, "Overflow should not grow the tracker");
    expectEquals(
        static_cast<int>(tracker.rt_getOverflowCount()), 1, "Overflow count should increment");
    expectEquals(static_cast<int>(tracker.rt_getHighWaterMark()),
        2,
        "High-water mark should reflect the largest successful active count");

    tracker.rt_clear();
    expectEquals(static_cast<int>(tracker.rt_getSize()), 0, "Clear should remove active notes");
    expectEquals(static_cast<int>(tracker.rt_getHighWaterMark()),
        2,
        "Clear should not reset the historical high-water mark");
    expectEquals(static_cast<int>(tracker.rt_getOverflowCount()),
        1,
        "Clear should not reset overflow accounting");
  }
};

static NoteTrackerTest noteTrackerTest;

} // namespace anthem
