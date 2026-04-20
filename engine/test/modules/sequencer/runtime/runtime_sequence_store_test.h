/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "modules/core/engine.h"
#include "modules/sequencer/events/event.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"
#include "modules/sequencer/runtime/transport.h"

#include <memory>
#include <optional>

namespace anthem {

class RuntimeSequenceStoreTest : public juce::UnitTest {
  static constexpr EntityId sequence1Id = 1;
  static constexpr EntityId sequence2Id = 2;
  static constexpr EntityId sequence3Id = 3;
  static constexpr EntityId track1Id = 11;
  static constexpr EntityId track2Id = 12;

  struct FakeProjectView : TransportProjectView {
    std::optional<LoopPointsSnapshot> loopPoints;

    std::optional<LoopPointsSnapshot> lookupLoopPoints(int64_t /* sequenceId */) const override {
      return loopPoints;
    }

    bool isPatternSequence(int64_t /* sequenceId */) const override {
      return false;
    }

    const SequenceEventListCollection* compiledSequence(int64_t /* sequenceId */) const override {
      return nullptr;
    }
  };

  struct FakeClock : TransportClock {
    double currentSampleRate() const override {
      return 48000.0;
    }
  };

  void installTransport(std::optional<LoopPointsSnapshot> loopPoints = std::nullopt) {
    Engine::cleanup();

    auto projectView = std::make_unique<FakeProjectView>();
    projectView->loopPoints = loopPoints;

    auto& engine = Engine::getInstance();
    engine.transport =
        std::make_unique<Transport>(std::move(projectView), std::make_unique<FakeClock>());
    engine.transport->prepareToProcess();
  }

  void preparePlayingTransport(
      double playheadPosition, std::optional<LoopPointsSnapshot> loopPoints = std::nullopt) {
    installTransport(loopPoints);

    auto& transport = *Engine::getInstance().transport;

    if (loopPoints.has_value()) {
      std::optional<int64_t> activeSequenceId = sequence1Id;
      transport.setActiveSequenceId(activeSequenceId);
    }

    transport.setIsPlaying(true);
    transport.rt_prepareForProcessingBlock();
    transport.rt_playhead = playheadPosition;
  }

  SequenceEventList createTrackWithInvalidation(double start, double end) {
    SequenceEventList track;
    track.invalidationRanges.emplace_back(start, end);
    return track;
  }

  void applyPendingRtUpdates(RuntimeSequenceStore* store) {
    auto nextMap = store->mapUpdateQueue.read();

    while (nextMap.has_value()) {
      auto* newMap = nextMap.value();
      auto* oldMap = store->rt_eventLists;

      store->rt_eventLists = newMap;
      store->mapDeletionQueue.add(oldMap);

      nextMap = store->mapUpdateQueue.read();
    }
  }

  void expectNoRetiredSnapshots(RuntimeSequenceStore* store) {
    expect(!store->mapDeletionQueue.read().has_value(), "No retired snapshots");
  }

  void expectNoPendingSnapshots(RuntimeSequenceStore* store, const juce::String& message) {
    expect(!store->mapUpdateQueue.read().has_value(), message);
  }

  void expectTrackInvalidation(RuntimeSequenceStore* store,
      EntityId sequenceId,
      EntityId trackId,
      bool expected,
      const juce::String& message) {
    auto* track = store->rt_getEventLists().sequences.at(sequenceId)->tracks.at(trackId);
    expect(track->rt_invalidationOccurred == expected, message);
  }
public:
  RuntimeSequenceStoreTest() : juce::UnitTest("RuntimeSequenceStoreTest", "Anthem") {}

  void runTest() override {
    testCreateAndReadEmptyStore();
    testMainThreadSnapshotUpdatesBeforeRtHandoff();
    testNoOpRemovalsDoNotPublishSnapshots();
    testAddAndRemoveSequences();
    testAddAndRemoveTracks();
    testRemoveTrackFromAllSequences();
    testRtInvalidationForCurrentBlock();
    testRtInvalidationIgnoresNonOverlappingRanges();
    testRtInvalidationForLoopStartRange();
    testCleanupAfterBlockClearsInvalidationFlags();
  }

  void testCreateAndReadEmptyStore() {
    beginTest("Create store and read empty event list map");

    auto* store = new RuntimeSequenceStore();
    auto& eventLists = store->rt_getEventLists();

    expect(eventLists.sequences.size() == 0, "Event lists are empty");
    expect(store->mapDeletionQueue.read().has_value() == false, "Deletion queue is empty");

    delete store;
  }

  void testMainThreadSnapshotUpdatesBeforeRtHandoff() {
    beginTest("Main-thread snapshot updates before RT handoff");

    auto* store = new RuntimeSequenceStore();

    SequenceEventList track;
    track.events.push_back(SequenceEvent{.offset = 2.0, .event = Event(NoteOnEvent())});

    store->addOrUpdateTrackInSequence(sequence1Id, track1Id, track);

    auto* mainThreadSequence = store->getSequenceEventList(sequence1Id);
    expect(mainThreadSequence != nullptr, "Main-thread sequence should be visible immediately");
    expect(mainThreadSequence->tracks.find(track1Id) != mainThreadSequence->tracks.end(),
        "Main-thread track should be visible immediately");
    expect(mainThreadSequence->tracks.at(track1Id)->events.size() == 1,
        "Main-thread track should include the new event");
    expect(store->rt_getEventLists().sequences.find(sequence1Id) ==
               store->rt_getEventLists().sequences.end(),
        "RT snapshot should not change before the handoff is consumed");

    applyPendingRtUpdates(store);
    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
  }

  void testNoOpRemovalsDoNotPublishSnapshots() {
    beginTest("No-op sequence and track removals do not publish snapshots");

    auto* store = new RuntimeSequenceStore();

    store->removeSequence(sequence1Id);
    expectNoPendingSnapshots(store, "Removing a missing sequence should not publish a snapshot");

    store->addOrUpdateSequence(sequence1Id, SequenceEventListCollection());
    applyPendingRtUpdates(store);
    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    store->removeTrackFromSequence(sequence1Id, track1Id);
    expectNoPendingSnapshots(
        store, "Removing a missing track from an existing sequence should not publish a snapshot");

    store->removeTrackFromSequence(sequence2Id, track1Id);
    expectNoPendingSnapshots(
        store, "Removing a track from a missing sequence should not publish a snapshot");

    delete store;
  }

  void testAddAndRemoveSequences() {
    beginTest("Add and remove sequences");

    auto* store = new RuntimeSequenceStore();

    store->addOrUpdateSequence(sequence1Id, SequenceEventListCollection());
    store->addOrUpdateSequence(sequence2Id, SequenceEventListCollection());

    // Simulate the audio thread consuming map updates.
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.sequences.size() == 2, "There are two sequences after add");
    expect(
        eventLists.sequences.find(sequence1Id) != eventLists.sequences.end(), "sequence1 exists");
    expect(
        eventLists.sequences.find(sequence2Id) != eventLists.sequences.end(), "sequence2 exists");

    // Cleanup for old maps returned by the simulated audio thread.
    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    store->removeSequence(sequence1Id);
    applyPendingRtUpdates(store);

    auto& eventListsAfterRemove = store->rt_getEventLists();
    expect(eventListsAfterRemove.sequences.size() == 1, "There is one sequence after remove");
    expect(
        eventListsAfterRemove.sequences.find(sequence1Id) == eventListsAfterRemove.sequences.end(),
        "sequence1 removed");
    expect(
        eventListsAfterRemove.sequences.find(sequence2Id) != eventListsAfterRemove.sequences.end(),
        "sequence2 still exists");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
  }

  void testAddAndRemoveTracks() {
    beginTest("Add, replace, and remove tracks in a sequence");

    auto* store = new RuntimeSequenceStore();

    store->addOrUpdateSequence(sequence1Id, SequenceEventListCollection());
    applyPendingRtUpdates(store);
    store->processDeletionQueues();

    SequenceEventList track1;
    track1.events.push_back(SequenceEvent{.offset = 0.0, .event = Event(NoteOnEvent())});

    store->addOrUpdateTrackInSequence(sequence1Id, track1Id, track1);
    store->addOrUpdateTrackInSequence(sequence1Id, track2Id, SequenceEventList());
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.sequences.at(sequence1Id)->tracks.size() == 2, "Two tracks were added");
    expect(eventLists.sequences.at(sequence1Id)->tracks.find(track1Id) !=
               eventLists.sequences.at(sequence1Id)->tracks.end(),
        "track1 exists");
    expect(eventLists.sequences.at(sequence1Id)->tracks.find(track2Id) !=
               eventLists.sequences.at(sequence1Id)->tracks.end(),
        "track2 exists");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    // Replace track2
    SequenceEventList replacement;
    replacement.events.push_back(SequenceEvent{.offset = 1.0, .event = Event(NoteOffEvent())});

    store->addOrUpdateTrackInSequence(sequence1Id, track2Id, replacement);
    applyPendingRtUpdates(store);

    auto& eventListsAfterReplace = store->rt_getEventLists();
    expect(eventListsAfterReplace.sequences.at(sequence1Id)->tracks.size() == 2,
        "Track count stays at two after replace");
    expect(
        eventListsAfterReplace.sequences.at(sequence1Id)->tracks.at(track2Id)->events.size() == 1,
        "Replaced track has one event");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    // Remove track1
    store->removeTrackFromSequence(sequence1Id, track1Id);
    applyPendingRtUpdates(store);

    auto& eventListsAfterRemove = store->rt_getEventLists();
    expect(eventListsAfterRemove.sequences.at(sequence1Id)->tracks.size() == 1,
        "One track remains after remove");
    expect(eventListsAfterRemove.sequences.at(sequence1Id)->tracks.find(track1Id) ==
               eventListsAfterRemove.sequences.at(sequence1Id)->tracks.end(),
        "track1 removed");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
  }

  void testRemoveTrackFromAllSequences() {
    beginTest("Remove one track from all sequences");

    auto* store = new RuntimeSequenceStore();

    store->addOrUpdateTrackInSequence(sequence1Id, track1Id, SequenceEventList());
    store->addOrUpdateTrackInSequence(sequence2Id, track1Id, SequenceEventList());
    store->addOrUpdateTrackInSequence(sequence3Id, track1Id, SequenceEventList());
    store->addOrUpdateTrackInSequence(sequence3Id, track2Id, SequenceEventList());

    applyPendingRtUpdates(store);

    auto& initialEventLists = store->rt_getEventLists();
    expect(initialEventLists.sequences.size() == 3, "Three sequences exist");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    store->removeTrackFromAllSequences(track1Id);
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.sequences.at(sequence1Id)->tracks.find(track1Id) ==
               eventLists.sequences.at(sequence1Id)->tracks.end(),
        "track1 removed from sequence1");
    expect(eventLists.sequences.at(sequence2Id)->tracks.find(track1Id) ==
               eventLists.sequences.at(sequence2Id)->tracks.end(),
        "track1 removed from sequence2");
    expect(eventLists.sequences.at(sequence3Id)->tracks.find(track1Id) ==
               eventLists.sequences.at(sequence3Id)->tracks.end(),
        "track1 removed from sequence3");
    expect(eventLists.sequences.at(sequence3Id)->tracks.find(track2Id) !=
               eventLists.sequences.at(sequence3Id)->tracks.end(),
        "track2 preserved in sequence3");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
  }

  void testRtInvalidationForCurrentBlock() {
    beginTest("RT handoff marks invalidation ranges that overlap the current block");

    preparePlayingTransport(4.0);

    auto* store = new RuntimeSequenceStore();
    store->addOrUpdateTrackInSequence(
        sequence1Id, track1Id, createTrackWithInvalidation(4.25, 4.75));

    store->rt_processSequenceChanges(250);

    expectTrackInvalidation(store,
        sequence1Id,
        track1Id,
        true,
        "An invalidation range inside the current block should be marked");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
    Engine::cleanup();
  }

  void testRtInvalidationIgnoresNonOverlappingRanges() {
    beginTest("RT handoff ignores invalidation ranges outside the current block");

    preparePlayingTransport(4.0);

    auto* store = new RuntimeSequenceStore();
    store->addOrUpdateTrackInSequence(sequence1Id, track1Id, createTrackWithInvalidation(6.0, 7.0));

    store->rt_processSequenceChanges(250);

    expectTrackInvalidation(store,
        sequence1Id,
        track1Id,
        false,
        "An invalidation range outside the current block should not be marked");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
    Engine::cleanup();
  }

  void testRtInvalidationForLoopStartRange() {
    beginTest("RT handoff checks the loop-start range when the block wraps");

    preparePlayingTransport(11.5, LoopPointsSnapshot{.start = 10.0, .end = 12.0});

    auto* store = new RuntimeSequenceStore();
    store->addOrUpdateTrackInSequence(
        sequence1Id, track1Id, createTrackWithInvalidation(10.25, 10.75));

    store->rt_processSequenceChanges(250);

    expectTrackInvalidation(store,
        sequence1Id,
        track1Id,
        true,
        "A wrapped block should check invalidations near the loop start");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
    Engine::cleanup();
  }

  void testCleanupAfterBlockClearsInvalidationFlags() {
    beginTest("RT cleanup clears per-block invalidation flags");

    preparePlayingTransport(4.0);

    auto* store = new RuntimeSequenceStore();
    store->addOrUpdateTrackInSequence(
        sequence1Id, track1Id, createTrackWithInvalidation(4.25, 4.75));

    store->rt_processSequenceChanges(250);
    expectTrackInvalidation(
        store, sequence1Id, track1Id, true, "The track should be marked before cleanup");

    store->rt_cleanupAfterBlock();
    expectTrackInvalidation(
        store, sequence1Id, track1Id, false, "The track should not stay marked after cleanup");

    store->processDeletionQueues();
    expectNoRetiredSnapshots(store);

    delete store;
    Engine::cleanup();
  }
};

static RuntimeSequenceStoreTest runtimeSequenceStoreTest;

} // namespace anthem
