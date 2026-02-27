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

#include "modules/sequencer/events/event.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

class RuntimeSequenceStoreTest : public juce::UnitTest {
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

  void expectNoPendingDeletions(AnthemRuntimeSequenceStore* store) {
    expect(store->pendingSequenceDeletions.empty(), "No pending sequence deletions");
    expect(store->pendingSequenceChannelDeletions.empty(), "No pending channel deletions");
  }

public:
  RuntimeSequenceStoreTest() : juce::UnitTest("RuntimeSequenceStoreTest", "Anthem") {}

  void runTest() override {
    testCreateAndReadEmptyStore();
    testAddAndRemoveSequences();
    testAddAndRemoveChannels();
    testRemoveChannelFromAllSequences();
  }

  void testCreateAndReadEmptyStore() {
    beginTest("Create store and read empty event list map");

    auto* store = new AnthemRuntimeSequenceStore();
    auto& eventLists = store->rt_getEventLists();

    expect(eventLists.size() == 0, "Event lists are empty");
    expect(store->mapDeletionQueue.read().has_value() == false, "Deletion queue is empty");

    delete store;
  }

  void testAddAndRemoveSequences() {
    beginTest("Add and remove sequences");

    auto* store = new AnthemRuntimeSequenceStore();

    store->addOrUpdateSequence("sequence1", SequenceEventListCollection());
    store->addOrUpdateSequence("sequence2", SequenceEventListCollection());

    // Simulate the audio thread consuming map updates.
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.size() == 2, "There are two sequences after add");
    expect(eventLists.find("sequence1") != eventLists.end(), "sequence1 exists");
    expect(eventLists.find("sequence2") != eventLists.end(), "sequence2 exists");

    // Cleanup for old maps returned by the simulated audio thread.
    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    store->removeSequence("sequence1");
    applyPendingRtUpdates(store);

    auto& eventListsAfterRemove = store->rt_getEventLists();
    expect(eventListsAfterRemove.size() == 1, "There is one sequence after remove");
    expect(eventListsAfterRemove.find("sequence1") == eventListsAfterRemove.end(), "sequence1 removed");
    expect(eventListsAfterRemove.find("sequence2") != eventListsAfterRemove.end(), "sequence2 still exists");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    delete store;
  }

  void testAddAndRemoveChannels() {
    beginTest("Add, replace, and remove channels in a sequence");

    auto* store = new AnthemRuntimeSequenceStore();

    store->addOrUpdateSequence("sequence1", SequenceEventListCollection());
    applyPendingRtUpdates(store);
    store->processDeletionQueues();

    SequenceEventList channel1;
    channel1.events->push_back(AnthemSequenceEvent {
      .offset = 0.0,
      .event = AnthemEvent(AnthemNoteOnEvent())
    });

    store->addOrUpdateChannelInSequence("sequence1", "channel1", channel1);
    store->addOrUpdateChannelInSequence("sequence1", "channel2", SequenceEventList());
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.at("sequence1").channels->size() == 2, "Two channels were added");
    expect(eventLists.at("sequence1").channels->find("channel1") != eventLists.at("sequence1").channels->end(), "channel1 exists");
    expect(eventLists.at("sequence1").channels->find("channel2") != eventLists.at("sequence1").channels->end(), "channel2 exists");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    // Replace channel2
    SequenceEventList replacement;
    replacement.events->push_back(AnthemSequenceEvent {
      .offset = 1.0,
      .event = AnthemEvent(AnthemNoteOffEvent())
    });

    store->addOrUpdateChannelInSequence("sequence1", "channel2", replacement);
    applyPendingRtUpdates(store);

    auto& eventListsAfterReplace = store->rt_getEventLists();
    expect(eventListsAfterReplace.at("sequence1").channels->size() == 2, "Channel count stays at two after replace");
    expect(eventListsAfterReplace.at("sequence1").channels->at("channel2").events->size() == 1, "Replaced channel has one event");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    // Remove channel1
    store->removeChannelFromSequence("sequence1", "channel1");
    applyPendingRtUpdates(store);

    auto& eventListsAfterRemove = store->rt_getEventLists();
    expect(eventListsAfterRemove.at("sequence1").channels->size() == 1, "One channel remains after remove");
    expect(eventListsAfterRemove.at("sequence1").channels->find("channel1") == eventListsAfterRemove.at("sequence1").channels->end(), "channel1 removed");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    delete store;
  }

  void testRemoveChannelFromAllSequences() {
    beginTest("Remove one channel from all sequences");

    auto* store = new AnthemRuntimeSequenceStore();

    store->addOrUpdateChannelInSequence("sequence1", "channel1", SequenceEventList());
    store->addOrUpdateChannelInSequence("sequence2", "channel1", SequenceEventList());
    store->addOrUpdateChannelInSequence("sequence3", "channel1", SequenceEventList());
    store->addOrUpdateChannelInSequence("sequence3", "channel2", SequenceEventList());

    applyPendingRtUpdates(store);

    auto& initialEventLists = store->rt_getEventLists();
    expect(initialEventLists.size() == 3, "Three sequences exist");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    store->removeChannelFromAllSequences("channel1");
    applyPendingRtUpdates(store);

    auto& eventLists = store->rt_getEventLists();
    expect(eventLists.at("sequence1").channels->find("channel1") == eventLists.at("sequence1").channels->end(), "channel1 removed from sequence1");
    expect(eventLists.at("sequence2").channels->find("channel1") == eventLists.at("sequence2").channels->end(), "channel1 removed from sequence2");
    expect(eventLists.at("sequence3").channels->find("channel1") == eventLists.at("sequence3").channels->end(), "channel1 removed from sequence3");
    expect(eventLists.at("sequence3").channels->find("channel2") != eventLists.at("sequence3").channels->end(), "channel2 preserved in sequence3");

    store->processDeletionQueues();
    expectNoPendingDeletions(store);

    delete store;
  }
};

static RuntimeSequenceStoreTest runtimeSequenceStoreTest;
