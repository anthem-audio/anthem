/*
  Copyright (C) 2025 

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

#include "runtime_sequence_store.h"

SequenceEventList::SequenceEventList() {
  events = new std::vector<AnthemSequenceEvent>();
}

void SequenceEventList::cleanUpInstance(SequenceEventList& instance) {
  delete instance.events;
}

SequenceEventListCollection::SequenceEventListCollection() {
  channels = new std::unordered_map<std::string, SequenceEventList>();
}

// This is essentially a destructor for SequenceEventListCollection. We just
// need very tight control over when specific event lists are deallocated. See
// the comments in the header file for more information.
void SequenceEventListCollection::cleanUpInstance(SequenceEventListCollection& instance) {
  for (auto& [key, seqListObj] : *instance.channels) {
    SequenceEventList::cleanUpInstance(seqListObj);
  }

  delete instance.channels;
}

AnthemRuntimeSequenceStore::SequenceIdToEventsMap& AnthemRuntimeSequenceStore::rt_getEventLists() {
  auto result = mapUpdateQueue.read();

  // Take all the updates from the queue, and push old values to the deletion
  // queue.
  while (result.has_value()) {
    auto* newMap = result.value();

    auto* oldMap = rt_eventLists;
    rt_eventLists = newMap;

    mapDeletionQueue.add(oldMap);

    result = mapUpdateQueue.read();
  }

  return *rt_eventLists;
}

AnthemRuntimeSequenceStore::AnthemRuntimeSequenceStore()
  : clearDeletionQueueTimedCallback(
      juce::TimedCallback([this]() {
        this->processMapDeletionQueue();
      })
    ),
    mapUpdateQueue(1024),
    mapDeletionQueue(1024)
{
  eventLists = new std::unordered_map<std::string, SequenceEventListCollection>();
  rt_eventLists = eventLists;

  pendingSequenceDeletions = std::unordered_map<AnthemRuntimeSequenceStore::SequenceIdToEventsMap*, SequenceEventListCollection>();
  pendingSequenceChannelDeletions = std::unordered_map<
    AnthemRuntimeSequenceStore::SequenceIdToEventsMap*,
    std::vector<
      std::tuple<
        std::optional<SequenceEventList>,
        std::unordered_map<std::string, SequenceEventList>*
      >
    >
  >();
}

// The audio thread MUST be stopped before cleaning this up. Otherwise, this
// will leak memory.
AnthemRuntimeSequenceStore::~AnthemRuntimeSequenceStore() {
  // Clean up any remaining maps in the deletion queue
  processMapDeletionQueue();

  for (auto& [key, seqListObj] : *eventLists) {
    SequenceEventListCollection::cleanUpInstance(seqListObj);
  }

  delete eventLists;
}

void AnthemRuntimeSequenceStore::processMapDeletionQueue() {
  auto nextMap = mapDeletionQueue.read();

  while (nextMap.has_value()) {
    auto* map = nextMap.value();

    // Check if there is a pending deletion for this map

    {
      auto it = pendingSequenceDeletions.find(map);
      if (it != pendingSequenceDeletions.end()) {
        SequenceEventListCollection::cleanUpInstance(it->second);
        pendingSequenceDeletions.erase(it);
      }
    }

    {
      auto it = pendingSequenceChannelDeletions.find(map);
      if (it != pendingSequenceChannelDeletions.end()) {
        for (auto& [oldEventsForChannel, oldChannelMap] : it->second) {
          if (oldEventsForChannel.has_value()) {
            SequenceEventList::cleanUpInstance(oldEventsForChannel.value());
          }

          delete oldChannelMap;
        }

        pendingSequenceChannelDeletions.erase(it);
      }
    }

    delete map;

    nextMap = mapDeletionQueue.read();
  }
}

void AnthemRuntimeSequenceStore::registerDeletionTimer() {
  clearDeletionQueueTimedCallback.startTimer(500);
}

void AnthemRuntimeSequenceStore::addOrUpdateSequence(const std::string& sequenceId, SequenceEventListCollection sequence) {
  auto newMap = new std::unordered_map<std::string, SequenceEventListCollection>(*eventLists);
  auto it = newMap->find(sequenceId);

  if (it != newMap->end()) {
    // If the sequence already exists, we need to replace it and add the old
    // sequence to the pending deletions map.
    pendingSequenceDeletions.insert_or_assign(eventLists, it->second);
  }

  newMap->insert_or_assign(sequenceId, sequence);

  mapUpdateQueue.add(newMap);

  // The audio thread still has the old pointer. We will clean it up when the
  // audio thread releases it, via the JUCE timer in this class.
  eventLists = newMap;
}

void AnthemRuntimeSequenceStore::removeSequence(const std::string& sequenceId) {
  auto it = eventLists->find(sequenceId);

  if (it != eventLists->end()) {
    auto newMap = new std::unordered_map<std::string, SequenceEventListCollection>(*eventLists);
    // If the sequence exists, we need to remove it and add it to the pending
    // deletions map.
    pendingSequenceDeletions.insert_or_assign(eventLists, it->second);
    newMap->erase(sequenceId);

    mapUpdateQueue.add(newMap);

    // The audio thread still has the old pointer. We will clean it up when the
    // audio thread releases it, via the JUCE timer in this class.
    eventLists = newMap;
  }
}

void AnthemRuntimeSequenceStore::addOrUpdateChannelInSequence(const std::string& sequenceId, const std::string& channelId, SequenceEventList channel) {
  auto newSequenceMap = new std::unordered_map<std::string, SequenceEventListCollection>(*eventLists);
  auto sequenceMapIt = newSequenceMap->find(sequenceId);

  // If the sequence doesn't exist, we need to add it.
  if (sequenceMapIt == newSequenceMap->end()) {
    SequenceEventListCollection sequence;

    newSequenceMap->insert_or_assign(sequenceId, sequence);

    sequenceMapIt = newSequenceMap->find(sequenceId);
  }

  // We need to replace the channel and add the old channel to the pending
  // deletions map.
  auto& sequence = sequenceMapIt->second;
  auto channelIt = sequence.channels->find(channelId);

  auto* newChannelsMap = new std::unordered_map<std::string, SequenceEventList>(*sequence.channels);

  {
    auto vec = std::vector<
      std::tuple<
        std::optional<SequenceEventList>,
        std::unordered_map<std::string, SequenceEventList>*
      >
    >();

    if (channelIt != sequence.channels->end()) {
      vec.push_back(std::make_tuple(channelIt->second, sequence.channels));
    } else {
      vec.push_back(std::make_tuple(std::nullopt, sequence.channels));
    }

    pendingSequenceChannelDeletions.insert_or_assign(eventLists, vec);
  }

  newChannelsMap->insert_or_assign(channelId, channel);

  SequenceEventListCollection newSequenceEventListObject;
  newSequenceEventListObject.channels = newChannelsMap;

  newSequenceMap->insert_or_assign(sequenceId, std::move(newSequenceEventListObject));

  mapUpdateQueue.add(newSequenceMap);

  // The audio thread still has the old pointer. We will clean it up when the
  // audio thread releases it, via the JUCE timer in this class.
  eventLists = newSequenceMap;
}

void AnthemRuntimeSequenceStore::removeChannelFromSequence(const std::string& sequenceId, const std::string& channelId) {
  auto sequenceMapIt = eventLists->find(sequenceId);
  if (sequenceMapIt == eventLists->end()) {
    return;
  }

  auto channelMapIt = sequenceMapIt->second.channels->find(channelId);
  if (channelMapIt == sequenceMapIt->second.channels->end()) {
    return;
  }

  auto newSequenceMap = new std::unordered_map<std::string, SequenceEventListCollection>(*eventLists);
  auto& sequence = newSequenceMap->at(sequenceId);

  auto newChannelsMap = new std::unordered_map<std::string, SequenceEventList>(*sequence.channels);
  
  {
    auto vec = std::vector<
      std::tuple<
        std::optional<SequenceEventList>,
        std::unordered_map<std::string, SequenceEventList>*
      >
    >();

    vec.push_back(std::make_tuple(channelMapIt->second, sequence.channels));

    pendingSequenceChannelDeletions.insert_or_assign(eventLists, vec);
  }

  newChannelsMap->erase(channelId);

  SequenceEventListCollection newSequenceEventListObject;
  newSequenceEventListObject.channels = newChannelsMap;

  newSequenceMap->insert_or_assign(sequenceId, std::move(newSequenceEventListObject));

  mapUpdateQueue.add(newSequenceMap);

  // The audio thread still has the old pointer. We will clean it up when the
  // audio thread releases it, via the JUCE timer in this class.
  eventLists = newSequenceMap;
}

void AnthemRuntimeSequenceStore::removeChannelFromAllSequences(const std::string& channelId) {
  auto newMap = new std::unordered_map<std::string, SequenceEventListCollection>(*eventLists);

  auto cleanupVec = std::vector<
    std::tuple<
      std::optional<SequenceEventList>,
      std::unordered_map<std::string, SequenceEventList>*
    >
  >();

  for (auto& [sequenceId, sequence] : *newMap) {
    auto channelIt = sequence.channels->find(channelId);

    if (channelIt != sequence.channels->end()) {
      auto newChannelsMap = new std::unordered_map<std::string, SequenceEventList>(*sequence.channels);

      cleanupVec.push_back(std::make_tuple(channelIt->second, sequence.channels));

      newChannelsMap->erase(channelId);

      SequenceEventListCollection newSequenceEventListObject;
      newSequenceEventListObject.channels = newChannelsMap;

      newMap->insert_or_assign(sequenceId, std::move(newSequenceEventListObject));
    }
  }

  pendingSequenceChannelDeletions.insert_or_assign(eventLists, cleanupVec);

  mapUpdateQueue.add(newMap);

  // The audio thread still has the old pointer. We will clean it up when the
  // audio thread releases it, via the JUCE timer in this class.
  eventLists = newMap;
}
