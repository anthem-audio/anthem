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

#include "modules/sequencer/events/event.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

class RuntimeSequenceStoreTest : public juce::UnitTest {
  static constexpr EntityId sequence1Id = 1;
  static constexpr EntityId sequence2Id = 2;
  static constexpr EntityId sequence3Id = 3;
  static constexpr EntityId track1Id = 11;
  static constexpr EntityId track2Id = 12;

  void applyPendingRtUpdates(AnthemRuntimeSequenceStore* store) {
    auto nextMap = store->mapUpdateQueue.read();

    while (nextMap.has_value()) {
      auto* newMap = nextMap.value();
      auto* oldMap = store->rt_eventLists;

      store->rt_eventLists = newMap;
      store->mapDeletionQueue.add(oldMap);

      nextMap = store->mapUpdateQueue.read();
    }
  }

  void expectNoRetiredSnapshots(AnthemRuntimeSequenceStore* store) {
    expect(!store->mapDeletionQueue.read().has_value(), "No retired snapshots");
  }
public:
  RuntimeSequenceStoreTest() : juce::UnitTest("RuntimeSequenceStoreTest", "Anthem") {}

  void runTest() override {
    testCreateAndReadEmptyStore();
    testAddAndRemoveSequences();
    testAddAndRemoveTracks();
    testRemoveTrackFromAllSequences();
  }

  void testCreateAndReadEmptyStore() {
    beginTest("Create store and read empty event list map");

    auto* store = new AnthemRuntimeSequenceStore();
    auto& eventLists = store->rt_getEventLists();

    expect(eventLists.sequences.size() == 0, "Event lists are empty");
    expect(store->mapDeletionQueue.read().has_value() == false, "Deletion queue is empty");

    delete store;
  }

  void testAddAndRemoveSequences() {
    beginTest("Add and remove sequences");

    auto* store = new AnthemRuntimeSequenceStore();

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

    auto* store = new AnthemRuntimeSequenceStore();

    store->addOrUpdateSequence(sequence1Id, SequenceEventListCollection());
    applyPendingRtUpdates(store);
    store->processDeletionQueues();

    SequenceEventList track1;
    track1.events.push_back(
        AnthemSequenceEvent{.offset = 0.0, .event = AnthemEvent(AnthemNoteOnEvent())});

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
    replacement.events.push_back(
        AnthemSequenceEvent{.offset = 1.0, .event = AnthemEvent(AnthemNoteOffEvent())});

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

    auto* store = new AnthemRuntimeSequenceStore();

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
};

static RuntimeSequenceStoreTest runtimeSequenceStoreTest;
