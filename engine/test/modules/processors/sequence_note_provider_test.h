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

#include "modules/processors/sequence_note_provider.h"

#include <juce_core/juce_core.h>

namespace anthem {

class SequenceNoteProviderTest : public juce::UnitTest {
  using RuntimeDependencies = SequenceNoteProviderProcessor::RuntimeDependencies;
  using RuntimeState = SequenceNoteProviderProcessor::RuntimeState;

  static constexpr int64_t trackId = 11;
  static constexpr SourceNoteId firstNoteId = 101;
  static constexpr SourceNoteId secondNoteId = 102;
  static constexpr LiveNoteId firstLiveId = 1001;
  static constexpr LiveNoteId secondLiveId = 1002;

  static SequenceEvent makeNoteOnEvent(double offset, SourceNoteId sourceId, int16_t pitch) {
    return SequenceEvent{
        .offset = offset,
        .sourceId = sourceId,
        .event = Event(NoteOnEvent(pitch, 0, 1.0f, 0.0f)),
    };
  }

  static SequenceEvent makeNoteOffEvent(double offset, SourceNoteId sourceId, int16_t pitch) {
    return SequenceEvent{
        .offset = offset,
        .sourceId = sourceId,
        .event = Event(NoteOffEvent(pitch, 0, 0.0f)),
    };
  }

  static void addTrack(SequenceEventListCollection& sequence,
      int64_t sourceTrackId,
      std::initializer_list<SequenceEvent> events,
      bool invalidationOccurred = false) {
    auto* track = new SequenceEventList();
    track->rt_invalidationOccurred = invalidationOccurred;

    for (const auto& event : events) {
      track->events.push_back(event);
    }

    sequence.setTrack(sourceTrackId, track);
  }

  static RuntimeDependencies buildDependencies(const SequenceEventListCollection* activeSequence) {
    return RuntimeDependencies{
        .rt_shouldStopSequenceNotes = false,
        .rt_playheadJumpEvent = nullptr,
        .rt_isPlaying = true,
        .rt_activeTrackId = std::nullopt,
        .rt_playhead = 0.0,
        .rt_loopStart = 0.0,
        .rt_loopEnd = std::numeric_limits<double>::infinity(),
        .rt_playheadJumpEventForLoop = nullptr,
        .rt_timingParams =
            sequencer_timing::TimingParams{
                .ticksPerQuarter = 4,
                .beatsPerMinute = 60.0,
                .sampleRate = 4.0,
            },
        .rt_activeSequence = activeSequence,
    };
  }

  static PlayheadJumpEvent buildJumpEvent(
      int64_t destinationTrackId, std::initializer_list<PlayheadJumpSequenceEvent> jumpEvents) {
    auto jumpEvent = PlayheadJumpEvent();
    jumpEvent.eventsToPlayAtJump.insert_or_assign(
        destinationTrackId, std::vector<PlayheadJumpSequenceEvent>(jumpEvents));
    return jumpEvent;
  }

  void expectEvent(EventBuffer& buffer,
      size_t index,
      int sampleOffset,
      EventType type,
      LiveNoteId liveId,
      int16_t pitch) {
    expect(buffer.getNumEvents() > index, "Expected event index should exist.");
    auto& event = buffer.getEvent(index);

    expectEquals(event.sampleOffset, sampleOffset, "Unexpected sample offset.");
    expectEquals(
        static_cast<int>(event.event.type), static_cast<int>(type), "Unexpected event type.");
    expectEquals(event.liveId, liveId, "Unexpected live note ID.");

    if (type == EventType::NoteOn) {
      expectEquals(event.event.noteOn.pitch, pitch, "Unexpected note-on pitch.");
    } else if (type == EventType::NoteOff) {
      expectEquals(event.event.noteOff.pitch, pitch, "Unexpected note-off pitch.");
    }
  }
public:
  SequenceNoteProviderTest() : juce::UnitTest("SequenceNoteProviderTest", "Anthem") {}

  void runTest() override {
    testSteadyPlaybackEmitsSequenceEvents();
    testStopAndJumpRestartsTrackedNotes();
    testInvalidationStopsTrackedNotesBeforeNewEvents();
    testLoopBoundaryStopsTrackedNotesAndAppliesLoopJump();
    testActiveTrackUsesNoTrackSequenceEvents();
    testFractionalOffsetsAreFloored();
    testChordEventsShareQuantizedSampleIndex();
    testLoopBoundaryAtBlockEndUsesLastSampleIndex();
  }

  void testSteadyPlaybackEmitsSequenceEvents() {
    beginTest("Steady playback emits note on and matching tracked note off");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence,
        trackId,
        {makeNoteOnEvent(1.0, firstNoteId, 60), makeNoteOffEvent(3.0, firstNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 4, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(
        static_cast<int>(buffer.getNumEvents()), 2, "Expected one note-on and one note-off.");
    expectEvent(buffer, 0, 1, EventType::NoteOn, firstLiveId, 60);
    expectEvent(buffer, 1, 3, EventType::NoteOff, firstLiveId, 60);
    expectEquals(static_cast<int>(state.rt_activeSequenceNotes.rt_getSize()),
        0,
        "Tracked notes should be empty after the matching note-off.");
  }

  void testStopAndJumpRestartsTrackedNotes() {
    beginTest("Stop and jump emit note-offs before jump-start note-ons");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence, trackId, {makeNoteOnEvent(0.0, firstNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    auto jumpEvent = buildJumpEvent(trackId,
        {PlayheadJumpSequenceEvent{
            .sequenceNoteId = secondNoteId,
            .event = Event(NoteOnEvent(67, 0, 1.0f, 0.0f)),
        }});

    buffer.clear();
    dependencies.rt_shouldStopSequenceNotes = true;
    dependencies.rt_playheadJumpEvent = &jumpEvent;
    dependencies.rt_isPlaying = false;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(static_cast<int>(buffer.getNumEvents()),
        2,
        "Stopping and jumping should emit one note-off and one restart note-on.");
    expectEvent(buffer, 0, 0, EventType::NoteOff, firstLiveId, 60);
    expectEvent(buffer, 1, 0, EventType::NoteOn, secondLiveId, 67);
    expectEquals(static_cast<int>(state.rt_activeSequenceNotes.rt_getSize()),
        1,
        "Jump-start note should remain tracked after the restart.");
  }

  void testInvalidationStopsTrackedNotesBeforeNewEvents() {
    beginTest("Invalidation stops tracked notes before reading replacement events");

    auto initialSequence = SequenceEventListCollection();
    addTrack(initialSequence, trackId, {makeNoteOnEvent(0.0, firstNoteId, 60)});

    auto dependencies = buildDependencies(&initialSequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    auto invalidatedSequence = SequenceEventListCollection();
    addTrack(invalidatedSequence, trackId, {makeNoteOnEvent(1.0, secondNoteId, 64)}, true);

    buffer.clear();
    dependencies.rt_activeSequence = &invalidatedSequence;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 2, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(static_cast<int>(buffer.getNumEvents()),
        2,
        "Invalidation should stop the old note and emit the replacement note.");
    expectEvent(buffer, 0, 0, EventType::NoteOff, firstLiveId, 60);
    expectEvent(buffer, 1, 1, EventType::NoteOn, secondLiveId, 64);
  }

  void testLoopBoundaryStopsTrackedNotesAndAppliesLoopJump() {
    beginTest("Loop boundary stops tracked notes and applies loop-start jump payload");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence, trackId, {makeNoteOnEvent(1.0, firstNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    dependencies.rt_playhead = 1.0;
    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    auto loopJumpEvent = buildJumpEvent(trackId,
        {PlayheadJumpSequenceEvent{
            .sequenceNoteId = firstNoteId,
            .event = Event(NoteOnEvent(60, 0, 1.0f, 0.0f)),
        }});

    buffer.clear();
    dependencies.rt_playhead = 4.0;
    dependencies.rt_loopStart = 2.0;
    dependencies.rt_loopEnd = 5.0;
    dependencies.rt_playheadJumpEventForLoop = &loopJumpEvent;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 2, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(static_cast<int>(buffer.getNumEvents()),
        2,
        "Crossing the loop should stop existing notes and restart loop-start notes.");
    expectEvent(buffer, 0, 1, EventType::NoteOff, firstLiveId, 60);
    expectEvent(buffer, 1, 1, EventType::NoteOn, secondLiveId, 60);
  }

  void testActiveTrackUsesNoTrackSequenceEvents() {
    beginTest("Active track reads the reserved no-track event list when available");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence, trackId, {makeNoteOnEvent(0.0, firstNoteId, 72)});
    addTrack(sequence, sequencer_track_ids::noTrack, {makeNoteOnEvent(0.0, secondNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    dependencies.rt_activeTrackId = trackId;

    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(
        static_cast<int>(buffer.getNumEvents()), 1, "Exactly one event should be emitted.");
    expectEvent(buffer, 0, 0, EventType::NoteOn, firstLiveId, 60);
  }

  void testFractionalOffsetsAreFloored() {
    beginTest("Sequence provider floors fractional event offsets");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence,
        trackId,
        {makeNoteOnEvent(1.9, firstNoteId, 60), makeNoteOffEvent(3.999, firstNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 4, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(
        static_cast<int>(buffer.getNumEvents()), 2, "Expected one note-on and one note-off.");
    expectEvent(buffer, 0, 1, EventType::NoteOn, firstLiveId, 60);
    expectEvent(buffer, 1, 3, EventType::NoteOff, firstLiveId, 60);
  }

  void testChordEventsShareQuantizedSampleIndex() {
    beginTest("Chord events at the same tick share the same quantized sample index");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence,
        trackId,
        {makeNoteOnEvent(1.75, firstNoteId, 60), makeNoteOnEvent(1.75, secondNoteId, 64)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 4, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(static_cast<int>(buffer.getNumEvents()), 2, "Expected two chord note-ons.");
    expectEvent(buffer, 0, 1, EventType::NoteOn, firstLiveId, 60);
    expectEvent(buffer, 1, 1, EventType::NoteOn, secondLiveId, 64);
  }

  void testLoopBoundaryAtBlockEndUsesLastSampleIndex() {
    beginTest("Loop boundary at block end uses the last valid sample index");

    auto sequence = SequenceEventListCollection();
    addTrack(sequence, trackId, {makeNoteOnEvent(1.0, firstNoteId, 60)});

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    EventBuffer buffer(8);
    LiveNoteId nextLiveId = firstLiveId;

    dependencies.rt_playhead = 1.0;
    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 1, [&nextLiveId]() { return nextLiveId++; });

    auto loopJumpEvent = buildJumpEvent(trackId,
        {PlayheadJumpSequenceEvent{
            .sequenceNoteId = firstNoteId,
            .event = Event(NoteOnEvent(60, 0, 1.0f, 0.0f)),
        }});

    buffer.clear();
    dependencies.rt_playhead = 4.0;
    dependencies.rt_loopStart = 2.0;
    dependencies.rt_loopEnd = 6.0;
    dependencies.rt_playheadJumpEventForLoop = &loopJumpEvent;

    SequenceNoteProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 2, [&nextLiveId]() { return nextLiveId++; });

    expectEquals(static_cast<int>(buffer.getNumEvents()),
        2,
        "Crossing at the block end should stop and restart on a valid sample index.");
    expectEvent(buffer, 0, 1, EventType::NoteOff, firstLiveId, 60);
    expectEvent(buffer, 1, 1, EventType::NoteOn, secondLiveId, 60);
  }
};

static SequenceNoteProviderTest sequenceNoteProviderTest;

} // namespace anthem
