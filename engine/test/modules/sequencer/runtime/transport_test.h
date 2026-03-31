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

#include "modules/sequencer/runtime/transport.h"

#include <juce_core/juce_core.h>

class TransportTest : public juce::UnitTest {
  static constexpr EntityId trackId = 11;
  static constexpr AnthemSourceNoteId firstNoteId = 101;
  static constexpr AnthemSourceNoteId secondNoteId = 102;

  static SequenceEventListCollection buildSequence(
    std::initializer_list<AnthemSequenceEvent> events
  ) {
    auto sequence = SequenceEventListCollection();
    auto track = SequenceEventList();

    for (const auto& event : events) {
      track.events->push_back(event);
    }

    sequence.tracks->insert_or_assign(trackId, std::move(track));
    return sequence;
  }

  static const std::vector<PlayheadJumpSequenceEvent>* getJumpEventsForTrack(
    const PlayheadJumpEvent& event
  ) {
    auto eventsIter = event.eventsToPlayAtJump.find(trackId);
    if (eventsIter == event.eventsToPlayAtJump.end()) {
      return nullptr;
    }

    return &eventsIter->second;
  }

public:
  TransportTest() : juce::UnitTest("TransportTest", "Anthem") {}

  void runTest() override {
    testJumpSnapshotExcludesNotesEndingAtBoundary();
    testJumpSnapshotKeepsSustainedNotesActive();
    testJumpSnapshotExcludesNotesStartingAtBoundary();
  }

  void testJumpSnapshotExcludesNotesEndingAtBoundary() {
    beginTest("Jump snapshot excludes notes that end at the boundary");

    auto sequence = buildSequence({
      AnthemSequenceEvent{
        .offset = 0.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))
      },
      AnthemSequenceEvent{
        .offset = 1.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))
      },
      AnthemSequenceEvent{
        .offset = 1.0,
        .sourceId = secondNoteId,
        .event = AnthemEvent(AnthemNoteOnEvent(62, 0, 1.0f, 0.0f))
      },
      AnthemSequenceEvent{
        .offset = 2.0,
        .sourceId = secondNoteId,
        .event = AnthemEvent(AnthemNoteOffEvent(62, 0, 0.0f))
      }
    });

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr, "No jump-start notes should be emitted at the boundary.");
  }

  void testJumpSnapshotKeepsSustainedNotesActive() {
    beginTest("Jump snapshot keeps sustained notes active");

    auto sequence = buildSequence({
      AnthemSequenceEvent{
        .offset = 0.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))
      },
      AnthemSequenceEvent{
        .offset = 2.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))
      }
    });

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents != nullptr, "A sustained note should still be active at the jump position.");
    expectEquals(static_cast<int>(jumpEvents->size()), 1, "Exactly one sustained note should restart.");
    expectEquals(jumpEvents->at(0).sequenceNoteId, firstNoteId, "The sustained note should be restarted.");
    expectEquals(
      static_cast<int>(jumpEvents->at(0).event.type),
      static_cast<int>(AnthemEventType::NoteOn),
      "Jump payload should only contain note-on events."
    );
  }

  void testJumpSnapshotExcludesNotesStartingAtBoundary() {
    beginTest("Jump snapshot excludes notes that start at the boundary");

    auto sequence = buildSequence({
      AnthemSequenceEvent{
        .offset = 1.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))
      },
      AnthemSequenceEvent{
        .offset = 2.0,
        .sourceId = firstNoteId,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))
      }
    });

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr, "Boundary note-ons should be emitted by normal block playback, not jump-start.");
  }
};

static TransportTest transportTest;
