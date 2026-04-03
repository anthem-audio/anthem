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
#include "modules/util/ring_buffer.h"

#include <cstdint>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>
#include <optional>
#include <tuple>
#include <unordered_map>
#include <vector>

namespace anthem_sequencer_track_ids {
inline constexpr int64_t noTrack = -1;
}

using EntityId = int64_t;

/*
  Anthem compiles each pattern and arrangement into a list of events for each
  track. When that pattern or arrangement is updated, its event lists are
  updated as well. The entire pattern can be updated, or a specific track can
  be surgically replaced.

  The goal of this file is to provide a way to:
    1. Store compiled sequences, either patterns or arrangements
    2. Allow these compiled sequences to be replaced, either in full or in part,
       in a real-time safe way

  The main class in this file is AnthemRuntimeSequenceStore. This class contains
  the API that other modules are expected to use. It is responsible for storing
  the compiled sequences, and managing the process of sending new sequences to
  the audio thread.
*/

// Stores a list of events meant for a single track.
//
// There will be at least one of these per sequence (pattern or arrangement),
// unless the sequence is completely empty.
class SequenceEventList {
private:
  JUCE_LEAK_DETECTOR(SequenceEventList)
public:
  // List of events for this track.
  std::vector<AnthemSequenceEvent>* events;

  // List of invalidation ranges for the current processing block, if any. If
  // this is set, it will be cleared when the processing block is read in,
  // and will be sent back for deletion.
  std::vector<std::tuple<double, double>>* invalidationRanges = nullptr;

  // Whether the old event list is invalid for the current processing block.
  //
  // Multiple recompiles may happen for a single processing block. Because of
  // this, the code that reads in new event lists needs to check against all
  // of them. It will set the list above to nullptr, and set this flag if any
  // of the relevant list updates have caused an invalidation.
  bool invalidationOccurred = false;

  SequenceEventList();

  // These are here so we don't automatically deallocate anything.
  ~SequenceEventList() = default;
  SequenceEventList(const SequenceEventList&) = default;
  SequenceEventList(SequenceEventList&&) = default;
  SequenceEventList& operator=(const SequenceEventList&) = default;
  SequenceEventList& operator=(SequenceEventList&&) = default;

  // Cleans up all heap memory held by a given SequenceEventList.
  static void cleanUpInstance(SequenceEventList& instance);
};

// Stores a set of events for a given sequence (either pattern or arrangement).
class SequenceEventListCollection {
private:
  JUCE_LEAK_DETECTOR(SequenceEventListCollection)
public:
  // Map of track ID to list of events for that track. If there is no entry
  // for a given track, it means that there are no events for that track.
  std::unordered_map<EntityId, SequenceEventList>* tracks;

  SequenceEventListCollection();

  // These are here so we don't automatically deallocate anything.
  ~SequenceEventListCollection() = default;
  SequenceEventListCollection(const SequenceEventListCollection&) = default;
  SequenceEventListCollection(SequenceEventListCollection&&) = default;
  SequenceEventListCollection& operator=(const SequenceEventListCollection&) = default;
  SequenceEventListCollection& operator=(SequenceEventListCollection&&) = default;

  // Cleans up all heap memory held by a given SequenceEventListCollection, both
  // direct and indirect.
  //
  // This method allows us to have full control over when these are deleted. The
  // flow is as follows:
  //   1. The main thread wants to replace the events for a sequence, so it
  //      first clones the AnthemRuntimeSequenceStore::eventLists map below.
  //      Note that this does not result in any of the actual sequence data
  //      being cloned, since each SequenceEventListCollection just holds a
  //      pointer to its track map. That pointer remains the same for every
  //      cloned SequenceEventListCollection.
  //   2. The main thread specifically wants to replace the item at sequence id
  //      "mySequenceId", so it prepares a new value for that key. This value
  //      includes a new map of tracks with new pointers to new data.
  //   3. The main thread grabs the old value at "mySequenceId", and stores it
  //      in AnthemRuntimeSequenceStore::pendingSequenceDeletions for deletion.
  //      Note again that this is just a pointer to the old map. The audio
  //      thread currently owns this pointer, and will for an unknown amount of
  //      time until it is able to release it, so we can't delete it yet.
  //   4. The main thread adds the pointer to the new map to
  //      AnthemRuntimeSequenceStore::mapUpdateQueue, to be picked up by the
  //      audio thread.
  //   5. The audio thread eventually releases control of the old map, and adds
  //      its pointer to AnthemRuntimeSequenceStore::mapDeletionQueue.
  //   6. Periodically, the main thread will check this queue. For each pointer
  //      it finds in the queue, it will delete the pointer, and clean up any
  //      associated entries in
  //      AnthemRuntimeSequenceStore::pendingSequenceDeletions by calling this
  //      method.
  //
  // To be clear, note that this method is called in the LAST step of the above
  // process. This means that the audio thread has already released the pointer
  // to the old map and it is ready to be deleted.
  static void cleanUpInstance(SequenceEventListCollection& instance);
};

// This class is responsible for storing sequences for the audio thread, and
// managing the process of sending new sequences to the audio thread.
//
// In Anthem, the sequence model is complex. To manage the complexity with
// respect to the audio thread, we "compile" sequences into time-sorted lists of
// events for each track. These lists are much easier to deal with from the
// sequencer's perspective. The runtime component of the sequencer doesn't even
// know about patterns - it just sees these event lists.
//
// We store event lists for each arrangement and for each pattern. When
// something is changed, e.g. some notes are moved around for a given pattern,
// we don't recompile the entire sequence. Instead, we just update the event
// lists for the relevant track.
class AnthemRuntimeSequenceStore {
  friend class RuntimeSequenceStoreTest;
private:
  JUCE_LEAK_DETECTOR(AnthemRuntimeSequenceStore)

  typedef std::unordered_map<EntityId, SequenceEventListCollection> SequenceIdToEventsMap;

  // Map of sequence ID to a set of event lists for that sequence.
  SequenceIdToEventsMap* eventLists;

  // The map currently being held by the audio thread. This will be the same as
  // eventLists, except when we are in the process of updating it.
  SequenceIdToEventsMap* rt_eventLists;

  // For sending new values of the map to the audio thread
  RingBuffer<SequenceIdToEventsMap*, 1024> mapUpdateQueue;

  // For the audio thread to send old values of the map to be deleted by the
  // main thread
  RingBuffer<SequenceIdToEventsMap*, 1024> mapDeletionQueue;

  // For the audio thread to send back invalidation range lists to be deleted
  // by the mmain thread
  RingBuffer<std::vector<std::tuple<double, double>>*, 1024> invalidationRangesDeletionQueue;

  juce::TimedCallback clearDeletionQueueTimedCallback;

  // When updating the eventLists map, we will clone it and replace one item.
  // This item may still be in use by the audio thread, so we add it here. When
  // the audio thread releases the old pointer, we will clean up the old
  // SequenceEventListCollection.
  std::unordered_map<SequenceIdToEventsMap*, SequenceEventListCollection> pendingSequenceDeletions;

  // The same as the above, except for replacing individual tracks in a
  // sequence. We will still clone the outer map in this case, except we will
  // also clone the inner map (the track map for that sequence). When we
  // replace the track, we add the old track to this map. When the audio thread
  // releases the old track, we will clean it up.
  std::unordered_map<SequenceIdToEventsMap*,
                     // This is a vector because removeTrack will remove a track in a bunch of
                     // sequences at once. We need to clean up all of them when the audio thread
                     // releases the old pointer.
                     std::vector<std::tuple<
                         // The track event list that was replaced - we need to clean up any heap
                         // memory it holds. If there was no entry for a given track when we
                         // replaced it, we don't need to clean up anything for it.
                         std::optional<SequenceEventList>,

                         // When we replace a track, we clone the map for that sequence (stored
                         // in SequenceEventListCollection). When the audio thread releases the old
                         // outer map (eventLists), we need to clean up the old inner map as well
                         // (SequenceEventListCollection::tracks).
                         std::unordered_map<EntityId, SequenceEventList>*>>>
      pendingSequenceTrackDeletions;

  void processDeletionQueues();
public:
  AnthemRuntimeSequenceStore();
  ~AnthemRuntimeSequenceStore();

  // Picks up any updates to the event lists map from the mapUpdateQueue.
  //
  // Must be run at the start of each processing block.
  void rt_processSequenceChanges(int bufferSize);

  // Gets a compiled sequence view on the main thread.
  //
  // This returns the current main-thread snapshot of the compiled event lists.
  // Callers must not hold onto the returned pointer across unrelated sequence
  // store updates.
  const SequenceEventListCollection* getSequenceEventList(EntityId sequenceId) const;

  // Gets the event lists map.
  //
  // Before returning the map, we check the mapUpdateQueue and while it is not
  // empty, we do the following until the update queue is empty:
  //   1. Pop the front of the queue
  //   2. Add the old map to the mapDeletionQueue, which will be picked up by
  //      the main thread for cleanup
  SequenceIdToEventsMap& rt_getEventLists();

  // Registers a timer with JUCE that will periodically check the
  // mapDeletionQueue and clean up any old maps that are ready to be deleted.
  //
  // This is separate from the constructor so we can not call it in tests.
  void registerDeletionTimer();

  // Adds or updates a sequence in the event lists map.
  //
  // This method is intended to be called from the main thread. It will clone
  // the current map, add the new sequence, and push the new map to the
  // mapUpdateQueue. If the sequence already exists, it will be replaced, and
  // the old sequence will be added to the pendingSequenceDeletions map.
  void addOrUpdateSequence(EntityId sequenceId, const SequenceEventListCollection& sequence);

  // Removes a sequence from the event lists map.
  void removeSequence(EntityId sequenceId);

  // Adds or updates a track in a sequence in the event lists map.
  //
  // This method is intended to be called from the main thread. It will clone
  // the current map, clone the track map for the given sequence, add the new
  // track, and push the new map to the mapUpdateQueue. If the track already
  // exists, it will be replaced, and the old track will be added to the
  // pendingSequenceTrackDeletions map.
  void
  addOrUpdateTrackInSequence(EntityId sequenceId, EntityId trackId, const SequenceEventList& track);

  // Removes a track from a sequence in the event lists map.
  void removeTrackFromSequence(EntityId sequenceId, EntityId trackId);

  // Removes every instance of the given track from every sequence.
  void removeTrackFromAllSequences(EntityId trackId);

  // Sends invalidation lists back to be deleted. Must be run at the end of each
  // processing block.
  void rt_cleanupAfterBlock();
};
