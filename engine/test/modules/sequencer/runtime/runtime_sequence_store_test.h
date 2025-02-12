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
public:
  RuntimeSequenceStoreTest() : juce::UnitTest("RuntimeSequenceStoreTest", "Anthem") {}

  void runTest() override {
    {
      beginTest("Create and delete runtime sequence store with no allocation");
      auto store = new AnthemRuntimeSequenceStore();
      delete store;
    }

    {
      beginTest("Test getting event lists");
      auto store = new AnthemRuntimeSequenceStore();
      auto& eventLists = store->rt_getEventLists();
      expect(eventLists.size() == 0, "Event lists are empty");
      delete store;
    }

    {
      beginTest("Check memory integrity of a simple sequence");

      auto store = new AnthemRuntimeSequenceStore();
      auto sequence = SequenceEventListCollection();

      auto eventList1 = SequenceEventList();
      eventList1.events->push_back(
      AnthemSequenceEvent {
        .time = AnthemSequenceTime {
          .ticks = 0,
          .fraction = 0.
        },
        .event = AnthemEvent {
          .type = AnthemEventType::NoteOn,
          .noteOn = AnthemNoteOnEvent()
        }
      });

      sequence.channels->insert_or_assign("channel1", eventList1);

      store->addOrUpdateSequence("sequence1", sequence);

      // At this point, the audio thread should be holding the old event list.

      expect(store->rt_eventLists != store->eventLists, "The event lists have been updated, but the audio thread has not picked up the new value");

      // We will simulate the audio thread calls synchronously here
      auto& eventLists = store->rt_getEventLists();

      expect(eventLists.size() == 1, "Event lists has one sequence");

      auto sequenceIt = eventLists.find("sequence1");
      expect(sequenceIt != eventLists.end(), "Sequence1 exists");

      auto& sequenceObj = sequenceIt->second;
      expect(sequenceObj.channels->size() == 1, "Sequence1 has one channel");

      auto channelIt = sequenceObj.channels->find("channel1");
      expect(channelIt != sequenceObj.channels->end(), "Channel1 exists");

      auto& channelObj = channelIt->second;
      expect(channelObj.events->size() == 1, "Channel1 has one event");

      auto& event = channelObj.events->at(0);
      expect(event.event.type == AnthemEventType::NoteOn, "Event is a NoteOn event");

      // There is nothing to clean up in this case, so we will abuse the friend
      // relationship between the test and the store to manually check that the
      // old event list was sent back by the rt_getEventLists call.

      auto pointerToCleanUp = store->mapDeletionQueue.read();
      expect(pointerToCleanUp.has_value(), "The audio thread has released the old event list");
      expect(pointerToCleanUp.value() != store->eventLists, "This is the old event list and not the new one");
      delete pointerToCleanUp.value();

      expect(store->mapDeletionQueue.read().has_value() == false, "There is only one item in the deletion queue");
    }

    {
      beginTest("Test adding and removing sequences");

      auto store = new AnthemRuntimeSequenceStore();

      store->addOrUpdateSequence("sequence1", SequenceEventListCollection());
      store->addOrUpdateSequence("sequence2", SequenceEventListCollection());
      store->addOrUpdateSequence("sequence3", SequenceEventListCollection());

      auto& eventLists = store->rt_getEventLists();

      expect(eventLists.size() == 3, "There are three sequences");

      // Check that the audio thread sent back the old event list maps
      auto pointerToCleanUp = store->mapDeletionQueue.read();
      expect(pointerToCleanUp.has_value(), "The audio thread has released the old event list (1)");
      delete pointerToCleanUp.value();

      pointerToCleanUp = store->mapDeletionQueue.read();
      expect(pointerToCleanUp.has_value(), "The audio thread has released the old event list (2)");
      delete pointerToCleanUp.value();

      pointerToCleanUp = store->mapDeletionQueue.read();
      expect(pointerToCleanUp.has_value(), "The audio thread has released the old event list (3)");
      delete pointerToCleanUp.value();

      expect(store->mapDeletionQueue.read().has_value() == false, "There are only three items in the deletion queue");

      // Since we didn't replace anything, there is no data to delete
      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");
      
      // Remove sequence1
      store->removeSequence("sequence1");

      auto& eventLists2 = store->rt_getEventLists();
      expect(eventLists2.size() == 2, "There are two sequences");

      expect(store->pendingSequenceDeletions.size() == 1, "There is one pending sequence deletion");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      // Replace sequence2
      store->addOrUpdateSequence("sequence2", SequenceEventListCollection());

      auto& eventLists3 = store->rt_getEventLists();
      expect(eventLists3.size() == 2, "There are two sequences");

      expect(store->pendingSequenceDeletions.size() == 1, "There is one pending sequence deletion");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      delete store;
    }

    {
      beginTest("Test adding and removing channel data for a sequence");

      auto store = new AnthemRuntimeSequenceStore();

      store->addOrUpdateSequence("sequence1", SequenceEventListCollection());

      store->addOrUpdateChannelInSequence("sequence1", "channel1", SequenceEventList());
      store->addOrUpdateChannelInSequence("sequence1", "channel2", SequenceEventList());
      store->addOrUpdateChannelInSequence("sequence1", "channel3", SequenceEventList());

      auto& eventLists = store->rt_getEventLists();

      expect(eventLists.size() == 1, "There is one sequence");
      expect(eventLists.at("sequence1").channels->size() == 3, "There are three channels");

      // We didn't replace anything, but we do clone the inner channels map, so
      // there will be three items to clean up in pendingSequenceChannelDeletions.
      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 3, "There are three pending channel deletions");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      // Remove channel1

      store->removeChannelFromSequence("sequence1", "channel1");

      auto& eventLists2 = store->rt_getEventLists();
      expect(eventLists2.size() == 1, "There is one sequence");
      expect(eventLists2.at("sequence1").channels->size() == 2, "There are two channels");

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 1, "There is one pending channel deletion");

      auto& vec = store->pendingSequenceChannelDeletions.begin()->second;
      expect(vec.size() == 1, "There is one channel to clean up");
      expect(std::get<0>(vec.at(0)).has_value() == true, "The channel event list to clean up is not empty, since we removed a channel");
      expect(std::get<1>(vec.at(0)) != nullptr, "The channel map to clean up is not null, since we always clone it");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      // Replace channel2

      store->addOrUpdateChannelInSequence("sequence1", "channel2", SequenceEventList());

      auto& eventLists3 = store->rt_getEventLists();
      expect(eventLists3.size() == 1, "There is one sequence");
      expect(eventLists3.at("sequence1").channels->size() == 2, "There are two channels");

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 1, "There is one pending channel deletion");

      auto& vec2 = store->pendingSequenceChannelDeletions.begin()->second;
      expect(vec2.size() == 1, "There is one channel to clean up");
      // The event list is empty, but it's still a vector that must be deallocated. We don't fill the event lists in this test.
      expect(std::get<0>(vec2.at(0)).has_value() == true, "The channel event list to clean up is not empty, since we replaced a channel");
      expect(std::get<1>(vec2.at(0)) != nullptr, "The channel map to clean up is not null, since we always clone it");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      delete store;
    }

    {
      beginTest("Test removing a channel from all sequences");

      auto store = new AnthemRuntimeSequenceStore();

      store->addOrUpdateChannelInSequence("sequence1", "channel1", SequenceEventList());
      store->addOrUpdateChannelInSequence("sequence2", "channel1", SequenceEventList());
      store->addOrUpdateChannelInSequence("sequence3", "channel1", SequenceEventList());

      auto& eventLists = store->rt_getEventLists();

      expect(eventLists.size() == 3, "There are three sequences");
      expect(eventLists.at("sequence1").channels->size() == 1, "Sequence1 has one channel");
      expect(eventLists.at("sequence2").channels->size() == 1, "Sequence2 has one channel");
      expect(eventLists.at("sequence3").channels->size() == 1, "Sequence3 has one channel");

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 3, "There are three pending channel deletions");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      store->removeChannelFromAllSequences("channel1");

      auto& eventLists2 = store->rt_getEventLists();

      expect(eventLists2.size() == 3, "There are three sequences");
      expect(eventLists2.at("sequence1").channels->size() == 0, "Sequence1 has no channels");
      expect(eventLists2.at("sequence2").channels->size() == 0, "Sequence2 has no channels");
      expect(eventLists2.at("sequence3").channels->size() == 0, "Sequence3 has no channels");

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 1, "There is one pending channel deletion");

      auto& vec = store->pendingSequenceChannelDeletions.begin()->second;
      expect(vec.size() == 3, "There are three channels to clean up");

      expect(std::get<0>(vec.at(0)).has_value() == true, "The first channel event list to clean up is not empty, since we removed a channel");
      expect(std::get<1>(vec.at(0)) != nullptr, "The first channel map to clean up is not null, since we always clone it");
      expect(std::get<0>(vec.at(1)).has_value() == true, "The second channel event list to clean up is not empty, since we removed a channel");
      expect(std::get<1>(vec.at(1)) != nullptr, "The second channel map to clean up is not null, since we always clone it");
      expect(std::get<0>(vec.at(2)).has_value() == true, "The third channel event list to clean up is not empty, since we removed a channel");
      expect(std::get<1>(vec.at(2)) != nullptr, "The third channel map to clean up is not null, since we always clone it");

      store->processMapDeletionQueue();

      expect(store->pendingSequenceDeletions.size() == 0, "There are no pending sequence deletions");
      expect(store->pendingSequenceChannelDeletions.size() == 0, "There are no pending channel deletions");

      delete store;      
    }
  }
};

static RuntimeSequenceStoreTest runtimeSequenceStoreTest;
