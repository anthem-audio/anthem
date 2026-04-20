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
#include <memory>
#include <unordered_map>
#include <unordered_set>

class TransportTest : public juce::UnitTest {
  static constexpr EntityId trackId = 11;
  static constexpr EntityId sequenceId = 200;
  static constexpr AnthemSourceNoteId firstNoteId = 101;
  static constexpr AnthemSourceNoteId secondNoteId = 102;

  struct FakeProjectView : TransportProjectView {
    std::unordered_map<EntityId, LoopPointsSnapshot> loopPoints;
    std::unordered_set<EntityId> patternSequences;
    std::unordered_map<EntityId, const SequenceEventListCollection*> compiledSequences;

    std::optional<LoopPointsSnapshot> lookupLoopPoints(int64_t id) const override {
      auto loopPointsIter = loopPoints.find(id);
      if (loopPointsIter == loopPoints.end()) {
        return std::nullopt;
      }

      return loopPointsIter->second;
    }

    bool isPatternSequence(int64_t id) const override {
      return patternSequences.find(id) != patternSequences.end();
    }

    const SequenceEventListCollection* compiledSequence(int64_t id) const override {
      auto compiledSequenceIter = compiledSequences.find(id);
      if (compiledSequenceIter == compiledSequences.end()) {
        return nullptr;
      }

      return compiledSequenceIter->second;
    }
  };

  struct FakeClock : TransportClock {
    double sampleRate = 48000.0;

    double currentSampleRate() const override {
      return sampleRate;
    }
  };

  static std::unique_ptr<SequenceEventListCollection> buildSequence(
      std::initializer_list<AnthemSequenceEvent> events, EntityId eventTrackId = trackId) {
    auto sequence = std::make_unique<SequenceEventListCollection>();
    auto* track = new SequenceEventList();

    for (const auto& event : events) {
      track->events.push_back(event);
    }

    sequence->setTrack(eventTrackId, track);
    return sequence;
  }

  static const std::vector<PlayheadJumpSequenceEvent>* getJumpEventsForTrack(
      const PlayheadJumpEvent& event, EntityId destinationTrackId = trackId) {
    auto eventsIter = event.eventsToPlayAtJump.find(destinationTrackId);
    if (eventsIter == event.eventsToPlayAtJump.end()) {
      return nullptr;
    }

    return &eventsIter->second;
  }

  static int drainPendingConfigCount(Transport& transport) {
    int count = 0;

    while (auto pendingConfig = transport.configBuffer.read()) {
      delete pendingConfig.value();
      count++;
    }

    return count;
  }

  static int drainRetiredConfigCount(Transport& transport) {
    int count = 0;

    while (auto retiredConfig = transport.configDeleteBuffer.read()) {
      delete retiredConfig.value();
      count++;
    }

    return count;
  }
public:
  TransportTest() : juce::UnitTest("TransportTest", "Anthem") {}

  void runTest() override {
    testJumpSnapshotExcludesNotesEndingAtBoundary();
    testJumpSnapshotKeepsSustainedNotesActive();
    testJumpSnapshotExcludesNotesStartingAtBoundary();
    testSetActiveSequenceBatchesLoopAndJumpUpdatesIntoSingleConfig();
    testClearingActiveSequenceClearsStartJumpPayload();
    testPrepareToProcessUsesInjectedClock();
    testSeekWhilePlayingPublishesJumpEvent();
    testStartPublishesStartJumpPayload();
    testStopReturnsToPlayheadStartAndStopsSequenceNotes();
    testLoopWrappingDuringBlockAdvance();
    testLoopStartJumpPayloadUsesCompiledSequence();
    testClearingActiveSequenceClearsLoopPoints();
    testConfigQueueReplacementUsesLatestConfig();
    testTimingParamsReflectTransportConfig();
    testJumpToWrapsSeekTargetIntoLoop();
    testActiveTrackChangeRebuildsJumpPayloadOnlyForPatterns();
  }

  void testJumpSnapshotExcludesNotesEndingAtBoundary() {
    beginTest("Jump snapshot excludes notes that end at the boundary");

    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 1.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))},
        AnthemSequenceEvent{.offset = 1.0,
            .sourceId = secondNoteId,
            .event = AnthemEvent(AnthemNoteOnEvent(62, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = secondNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(62, 0, 0.0f))}});

    auto jumpEvent = buildPlayheadJumpEvent(*sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr, "No jump-start notes should be emitted at the boundary.");
  }

  void testJumpSnapshotKeepsSustainedNotesActive() {
    beginTest("Jump snapshot keeps sustained notes active");

    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});

    auto jumpEvent = buildPlayheadJumpEvent(*sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents != nullptr, "A sustained note should still be active at the jump position.");
    expectEquals(
        static_cast<int>(jumpEvents->size()), 1, "Exactly one sustained note should restart.");
    expectEquals(
        jumpEvents->at(0).sequenceNoteId, firstNoteId, "The sustained note should be restarted.");
    expectEquals(static_cast<int>(jumpEvents->at(0).event.type),
        static_cast<int>(AnthemEventType::NoteOn),
        "Jump payload should only contain note-on events.");
  }

  void testJumpSnapshotExcludesNotesStartingAtBoundary() {
    beginTest("Jump snapshot excludes notes that start at the boundary");

    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 1.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});

    auto jumpEvent = buildPlayheadJumpEvent(*sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr,
        "Boundary note-ons should be emitted by normal block playback, not jump-start.");
  }

  void testSetActiveSequenceBatchesLoopAndJumpUpdatesIntoSingleConfig() {
    beginTest("Setting the active sequence batches loop and jump updates into one config");

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints.insert_or_assign(sequenceId, LoopPointsSnapshot{.start = 4, .end = 8});
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    transport.config.playheadStart = 6.0;

    expectEquals(
        drainPendingConfigCount(transport), 1, "Constructor should enqueue one initial config.");

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);

    expect(transport.config.hasLoop, "Loop points should be loaded into the local config.");
    expectEquals(
        transport.config.loopStart, 4.0, "Loop start should come from the active sequence.");
    expectEquals(transport.config.loopEnd, 8.0, "Loop end should come from the active sequence.");
    expectEquals(drainPendingConfigCount(transport),
        1,
        "setActiveSequenceId() should publish a single combined config snapshot.");
  }

  void testClearingActiveSequenceClearsStartJumpPayload() {
    beginTest("Clearing the active sequence clears the cached start jump payload");

    auto projectView = std::make_unique<FakeProjectView>();
    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});
    projectView->compiledSequences.insert_or_assign(sequenceId, sequence.get());
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    transport.config.playheadStart = 1.0;

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);

    auto* jumpEventsBeforeClear = getJumpEventsForTrack(transport.config.playheadJumpEventForStart);
    expect(jumpEventsBeforeClear != nullptr,
        "The cached start payload should include sustained notes.");
    expectEquals(transport.config.playheadJumpEventForStart.newPlayheadPosition,
        1.0,
        "The cached start payload should target the current playhead start.");

    std::optional<int64_t> noActiveSequence = std::nullopt;
    transport.setActiveSequenceId(noActiveSequence);

    auto* jumpEventsAfterClear = getJumpEventsForTrack(transport.config.playheadJumpEventForStart);
    expect(jumpEventsAfterClear == nullptr,
        "Clearing the active sequence should remove cached jump-start note payloads.");
    expectEquals(transport.config.playheadJumpEventForStart.newPlayheadPosition,
        1.0,
        "Clearing the active sequence should preserve the stored playhead-start position.");
  }

  void testPrepareToProcessUsesInjectedClock() {
    beginTest("prepareToProcess uses the injected clock and resets the sample counter");

    auto projectView = std::make_unique<FakeProjectView>();
    auto clock = std::make_unique<FakeClock>();
    clock->sampleRate = 96000.0;
    Transport transport(std::move(projectView), std::move(clock));

    transport.rt_sampleCounter = 123;
    transport.prepareToProcess();

    auto timingParams = transport.rt_getTimingParams();
    expectEquals(timingParams.sampleRate, 96000.0, "Sample rate should come from the clock.");
    expectEquals(transport.rt_sampleCounter, static_cast<int64_t>(0), "Sample counter is reset.");
  }

  void testSeekWhilePlayingPublishesJumpEvent() {
    beginTest("Seek while playing publishes a jump event for the processing block");

    auto projectView = std::make_unique<FakeProjectView>();
    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});
    projectView->compiledSequences.insert_or_assign(sequenceId, sequence.get());
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);
    transport.setIsPlaying(true);
    transport.rt_prepareForProcessingBlock();
    transport.rt_advancePlayhead(0);

    transport.jumpTo(1.0);
    transport.rt_prepareForProcessingBlock();

    expectEquals(transport.rt_playhead, 1.0, "Seek should update the RT playhead.");
    expect(transport.rt_playheadJumpOrPauseOccurred, "Seek should flag a jump for this block.");
    expect(transport.rt_shouldStopSequenceNotes, "Seek should stop previously emitted notes.");
    expect(transport.rt_playheadJumpEvent != nullptr, "Seek should publish a jump payload.");

    auto* jumpEvents = getJumpEventsForTrack(*transport.rt_playheadJumpEvent);
    expect(jumpEvents != nullptr, "Seek payload should restart sustained notes at the new point.");
    expectEquals(static_cast<int>(jumpEvents->size()), 1, "Exactly one note should restart.");
  }

  void testStartPublishesStartJumpPayload() {
    beginTest("Starting playback publishes the cached start jump payload");

    auto projectView = std::make_unique<FakeProjectView>();
    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 2.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});
    projectView->compiledSequences.insert_or_assign(sequenceId, sequence.get());
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);
    transport.setPlayheadStart(1.0);
    transport.setIsPlaying(true);

    transport.rt_prepareForProcessingBlock();

    expect(transport.rt_playheadJumpEvent != nullptr,
        "Starting playback should publish the cached jump-start payload.");

    auto* jumpEvents = getJumpEventsForTrack(*transport.rt_playheadJumpEvent);
    expect(jumpEvents != nullptr, "Start payload should restart sustained notes.");
    expectEquals(static_cast<int>(jumpEvents->size()), 1, "Exactly one note should restart.");
    expectEquals(
        jumpEvents->at(0).sequenceNoteId, firstNoteId, "The sustained note should restart.");
  }

  void testStopReturnsToPlayheadStartAndStopsSequenceNotes() {
    beginTest("Stop returns to playheadStart and stops sequence notes");

    auto projectView = std::make_unique<FakeProjectView>();
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));
    transport.prepareToProcess();

    transport.setPlayheadStart(96.0);
    transport.jumpTo(96.0);
    transport.rt_prepareForProcessingBlock();
    expectEquals(transport.rt_playhead, 96.0, "Initial stopped seek should restore playhead.");
    transport.rt_advancePlayhead(0);

    transport.setIsPlaying(true);
    transport.rt_prepareForProcessingBlock();
    transport.rt_advancePlayhead(250);
    expectEquals(transport.rt_playhead, 97.0, "Playing transport should advance by one tick.");

    transport.setIsPlaying(false);
    transport.rt_prepareForProcessingBlock();

    expectEquals(transport.rt_playhead, 96.0, "Stopping should return to the start position.");
    expect(transport.rt_playheadJumpOrPauseOccurred, "Stopping should flag a jump/pause.");
    expect(transport.rt_shouldStopSequenceNotes, "Stopping should stop sequence-owned notes.");
  }

  void testLoopWrappingDuringBlockAdvance() {
    beginTest("Loop wrapping during block advancement wraps to the loop start");

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints.insert_or_assign(
        sequenceId, LoopPointsSnapshot{.start = 10, .end = 14});
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));
    transport.prepareToProcess();

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);
    transport.setIsPlaying(true);
    transport.rt_prepareForProcessingBlock();

    transport.rt_playhead = 13.0;
    transport.rt_advancePlayhead(500);

    expectEquals(transport.rt_playhead, 11.0, "Advancing past loop end should wrap.");
    expectEquals(transport.rt_sampleCounter,
        static_cast<int64_t>(500),
        "Sample counter should advance with processed samples.");
  }

  void testLoopStartJumpPayloadUsesCompiledSequence() {
    beginTest("Loop-start jump payload uses the compiled active sequence");

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints.insert_or_assign(sequenceId, LoopPointsSnapshot{.start = 4, .end = 8});
    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
        AnthemSequenceEvent{.offset = 6.0,
            .sourceId = firstNoteId,
            .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});
    projectView->compiledSequences.insert_or_assign(sequenceId, sequence.get());
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);

    expect(transport.config.playheadJumpEventForLoop.has_value(),
        "Loop config should include a loop-start jump payload.");

    auto* jumpEvents = getJumpEventsForTrack(transport.config.playheadJumpEventForLoop.value());
    expect(jumpEvents != nullptr, "Sustained notes at loop start should be included.");
    expectEquals(static_cast<int>(jumpEvents->size()), 1, "Exactly one loop-start note restarts.");
    expectEquals(jumpEvents->at(0).sequenceNoteId, firstNoteId, "The sustained note restarts.");
  }

  void testClearingActiveSequenceClearsLoopPoints() {
    beginTest("Clearing the active sequence clears loop points");

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints.insert_or_assign(sequenceId, LoopPointsSnapshot{.start = 4, .end = 8});
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);

    expect(transport.config.hasLoop, "Active sequence should load loop points.");
    expect(transport.config.playheadJumpEventForLoop.has_value(),
        "Active sequence should build loop-start jump payload storage.");

    std::optional<int64_t> noActiveSequence = std::nullopt;
    transport.setActiveSequenceId(noActiveSequence);

    expect(!transport.config.hasLoop, "Clearing active sequence should clear hasLoop.");
    expectEquals(transport.config.loopStart, 0.0, "Loop start should reset.");
    expectEquals(transport.config.loopEnd,
        std::numeric_limits<double>::infinity(),
        "Loop end should reset.");
    expect(!transport.config.playheadJumpEventForLoop.has_value(),
        "Loop-start jump payload should be cleared.");
  }

  void testConfigQueueReplacementUsesLatestConfig() {
    beginTest("Config queue replacement uses the latest pending config");

    auto projectView = std::make_unique<FakeProjectView>();
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    transport.setBeatsPerMinute(130.0);
    transport.setBeatsPerMinute(140.0);
    transport.rt_prepareForProcessingBlock();

    expectEquals(
        transport.rt_config->beatsPerMinute, 140.0, "RT config should use the newest value.");
    expectEquals(drainRetiredConfigCount(transport),
        3,
        "Superseded pending configs and the old RT config should be retired.");
  }

  void testTimingParamsReflectTransportConfig() {
    beginTest("Timing params reflect transport config");

    auto projectView = std::make_unique<FakeProjectView>();
    auto clock = std::make_unique<FakeClock>();
    clock->sampleRate = 96000.0;
    Transport transport(std::move(projectView), std::move(clock));
    transport.prepareToProcess();

    transport.setTicksPerQuarter(192);
    transport.setBeatsPerMinute(90.0);
    transport.rt_prepareForProcessingBlock();

    auto timingParams = transport.rt_getTimingParams();
    expectEquals(timingParams.ticksPerQuarter,
        static_cast<int64_t>(192),
        "Timing params should use the latest TPQ.");
    expectEquals(timingParams.beatsPerMinute, 90.0, "Timing params should use the latest BPM.");
    expectEquals(
        timingParams.sampleRate, 96000.0, "Timing params should use the clock sample rate.");
  }

  void testJumpToWrapsSeekTargetIntoLoop() {
    beginTest("jumpTo wraps seek targets into the active loop");

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints.insert_or_assign(
        sequenceId, LoopPointsSnapshot{.start = 10, .end = 14});
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);
    transport.jumpTo(17.0);
    transport.rt_prepareForProcessingBlock();

    expectEquals(transport.rt_playhead, 13.0, "Seek target should wrap into the active loop.");
  }

  void testActiveTrackChangeRebuildsJumpPayloadOnlyForPatterns() {
    beginTest("Active track changes rebuild jump payloads only for pattern playback");

    auto projectView = std::make_unique<FakeProjectView>();
    auto* projectViewPtr = projectView.get();
    auto sequence = buildSequence({AnthemSequenceEvent{.offset = 0.0,
                                       .sourceId = firstNoteId,
                                       .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
                                      AnthemSequenceEvent{.offset = 2.0,
                                          .sourceId = firstNoteId,
                                          .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}},
        anthem_sequencer_track_ids::noTrack);
    projectView->compiledSequences.insert_or_assign(sequenceId, sequence.get());
    auto clock = std::make_unique<FakeClock>();
    Transport transport(std::move(projectView), std::move(clock));

    transport.config.playheadStart = 1.0;

    std::optional<int64_t> activeSequenceId = sequenceId;
    transport.setActiveSequenceId(activeSequenceId);

    std::optional<int64_t> activeTrackId = trackId;
    transport.setActiveTrackId(activeTrackId);

    auto* jumpEventsBeforePattern =
        getJumpEventsForTrack(transport.config.playheadJumpEventForStart);
    expect(jumpEventsBeforePattern == nullptr,
        "Non-pattern active track changes should not rebuild no-track routing payloads.");

    projectViewPtr->patternSequences.insert(sequenceId);
    transport.setActiveTrackId(activeTrackId);

    auto* jumpEventsAfterPattern =
        getJumpEventsForTrack(transport.config.playheadJumpEventForStart);
    expect(jumpEventsAfterPattern != nullptr,
        "Pattern active track changes should rebuild no-track routing payloads.");
    expectEquals(static_cast<int>(jumpEventsAfterPattern->size()),
        1,
        "The rebuilt payload should route one sustained note to the active track.");
  }
};

static TransportTest transportTest;
