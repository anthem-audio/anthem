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

#include "modules/core/anthem.h"
#include "modules/core/project.h"
#include "modules/sequencer/runtime/transport.h"

#include <juce_core/juce_core.h>

class TransportTest : public juce::UnitTest {
  static constexpr EntityId trackId = 11;
  static constexpr EntityId sequenceId = 200;
  static constexpr AnthemSourceNoteId firstNoteId = 101;
  static constexpr AnthemSourceNoteId secondNoteId = 102;

  static SequenceEventListCollection
  buildSequence(std::initializer_list<AnthemSequenceEvent> events) {
    auto sequence = SequenceEventListCollection();
    auto track = SequenceEventList();

    for (const auto& event : events) {
      track.events->push_back(event);
    }

    sequence.tracks->insert_or_assign(trackId, std::move(track));
    return sequence;
  }

  static const std::vector<PlayheadJumpSequenceEvent>*
  getJumpEventsForTrack(const PlayheadJumpEvent& event) {
    auto eventsIter = event.eventsToPlayAtJump.find(trackId);
    if (eventsIter == event.eventsToPlayAtJump.end()) {
      return nullptr;
    }

    return &eventsIter->second;
  }

  static std::shared_ptr<Sequencer> createSequencerModel() {
    return std::make_shared<Sequencer>(SequencerModelImpl{
        .ticksPerQuarter = 96,
        .beatsPerMinuteRaw = 12000,
        .patterns =
            std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<PatternModel>>>(),
        .activePatternID = std::nullopt,
        .activeTrackID = std::nullopt,
        .arrangements =
            std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<ArrangementModel>>>(),
        .arrangementOrder = std::make_shared<AnthemModelVector<int64_t>>(),
        .activeArrangementID = std::nullopt,
        .activeTransportSequenceID = std::nullopt,
        .defaultTimeSignature = std::make_shared<TimeSignatureModel>(TimeSignatureModelImpl{
            .numerator = 4,
            .denominator = 4,
        }),
        .playbackStartPosition = 0,
        .isPlaying = false,
    });
  }

  static std::shared_ptr<Project> createProject() {
    return std::make_shared<Project>(ProjectModelImpl{
        .sequence = createSequencerModel(),
        .processingGraph = std::make_shared<ProcessingGraphModel>(ProcessingGraphModelImpl{
            .nodes = std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<Node>>>(),
            .connections = std::make_shared<
                AnthemModelUnorderedMap<int64_t, std::shared_ptr<NodeConnection>>>(),
            .masterOutputNodeId = 0,
        }),
        .masterOutputNodeId = std::nullopt,
        .tracks = std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<TrackModel>>>(),
        .trackOrder = std::make_shared<AnthemModelVector<int64_t>>(),
        .sendTrackOrder = std::make_shared<AnthemModelVector<int64_t>>(),
        .filePath = std::nullopt,
        .isDirty = false,
    });
  }

  static std::shared_ptr<PatternModel> createPatternWithLoopPoints(int64_t start, int64_t end) {
    return std::make_shared<PatternModel>(PatternModelImpl{
        .id = sequenceId,
        .name = "Pattern",
        .color = std::make_shared<AnthemColor>(AnthemColorImpl{
            .hue = 0.0,
            .palette = AnthemColorPaletteKind::normal,
        }),
        .notes = std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<NoteModel>>>(),
        .automation = std::make_shared<AutomationLaneModel>(AutomationLaneModelImpl{
            .points = std::make_shared<AnthemModelVector<std::shared_ptr<AutomationPointModel>>>(),
        }),
        .timeSignatureChanges =
            std::make_shared<AnthemModelVector<std::shared_ptr<TimeSignatureChangeModel>>>(),
        .loopPoints = std::make_shared<LoopPointsModel>(LoopPointsModelImpl{
            .start = start,
            .end = end,
        }),
    });
  }

  static void resetAnthemForTransportTests() {
    Anthem::cleanup();

    auto& anthem = Anthem::getInstance();
    anthem.project = createProject();
    anthem.sequenceStore = std::make_unique<AnthemRuntimeSequenceStore>();
    anthem.transport = std::make_unique<Transport>();
  }

  static int drainPendingConfigCount(Transport& transport) {
    int count = 0;

    while (transport.configBuffer.read().has_value()) {
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
  }

  void testJumpSnapshotExcludesNotesEndingAtBoundary() {
    beginTest("Jump snapshot excludes notes that end at the boundary");

    auto sequence = buildSequence(
        {AnthemSequenceEvent{.offset = 0.0,
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

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr, "No jump-start notes should be emitted at the boundary.");
  }

  void testJumpSnapshotKeepsSustainedNotesActive() {
    beginTest("Jump snapshot keeps sustained notes active");

    auto sequence = buildSequence(
        {AnthemSequenceEvent{.offset = 0.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
         AnthemSequenceEvent{.offset = 2.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
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

    auto sequence = buildSequence(
        {AnthemSequenceEvent{.offset = 1.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
         AnthemSequenceEvent{.offset = 2.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});

    auto jumpEvent = buildPlayheadJumpEvent(sequence, std::nullopt, 1.0);
    auto* jumpEvents = getJumpEventsForTrack(jumpEvent);

    expect(jumpEvents == nullptr,
           "Boundary note-ons should be emitted by normal block playback, not jump-start.");
  }

  void testSetActiveSequenceBatchesLoopAndJumpUpdatesIntoSingleConfig() {
    beginTest("Setting the active sequence batches loop and jump updates into one config");

    resetAnthemForTransportTests();

    auto& anthem = Anthem::getInstance();
    anthem.project->sequence()->patterns()->insert_or_assign(sequenceId,
                                                             createPatternWithLoopPoints(4, 8));

    auto& transport = *anthem.transport;
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

    Anthem::cleanup();
  }

  void testClearingActiveSequenceClearsStartJumpPayload() {
    beginTest("Clearing the active sequence clears the cached start jump payload");

    resetAnthemForTransportTests();

    auto& anthem = Anthem::getInstance();
    auto sequence = buildSequence(
        {AnthemSequenceEvent{.offset = 0.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f))},
         AnthemSequenceEvent{.offset = 2.0,
                             .sourceId = firstNoteId,
                             .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f))}});
    anthem.sequenceStore->addOrUpdateSequence(sequenceId, sequence);

    auto& transport = *anthem.transport;
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
    expectEquals(
        transport.config.playheadJumpEventForStart.newPlayheadPosition,
        1.0,
        "Clearing the active sequence should preserve the stored playhead-start position.");

    Anthem::cleanup();
  }
};

static TransportTest transportTest;
