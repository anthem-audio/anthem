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
#include <tuple>
#include <unordered_map>
#include <vector>

namespace anthem {

namespace sequencer_track_ids {
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
  std::vector<SequenceEvent> events;

  // List of invalidation ranges to check when this event list is published to
  // the audio thread.
  std::vector<std::tuple<double, double>> invalidationRanges;

  // Whether this event list is invalid for the current processing block.
  bool rt_invalidationOccurred = false;

  // Number of live track snapshots that reference this event list. This is only
  // mutated on the main thread.
  int snapshotRefCount = 0;

  SequenceEventList();
  SequenceEventList(const SequenceEventList& other);
  SequenceEventList(SequenceEventList&& other) noexcept;
  SequenceEventList& operator=(const SequenceEventList& other);
  SequenceEventList& operator=(SequenceEventList&& other) noexcept;

  ~SequenceEventList() = default;
};

struct ChangedSequenceTrack {
  EntityId sequenceId;
  EntityId trackId;
  std::vector<std::tuple<double, double>> invalidationRanges;
};

// Stores a set of event lists for a given sequence (either pattern or
// arrangement).
class SequenceEventListCollection {
private:
  JUCE_LEAK_DETECTOR(SequenceEventListCollection)
public:
  // Map of track ID to list of events for that track. If there is no entry
  // for a given track, it means that there are no events for that track.
  std::unordered_map<EntityId, SequenceEventList*> tracks;

  // Number of live store snapshots that reference this track map. This is only
  // mutated on the main thread.
  int snapshotRefCount = 0;

  SequenceEventListCollection();
  ~SequenceEventListCollection();

  SequenceEventListCollection(const SequenceEventListCollection&) = delete;
  SequenceEventListCollection(SequenceEventListCollection&&) = delete;
  SequenceEventListCollection& operator=(const SequenceEventListCollection&) = delete;
  SequenceEventListCollection& operator=(SequenceEventListCollection&&) = delete;

  SequenceEventListCollection* clone() const;
  void setTrack(EntityId trackId, SequenceEventList* track);
  void removeTrack(EntityId trackId);
};

class SequenceStoreSnapshot {
private:
  JUCE_LEAK_DETECTOR(SequenceStoreSnapshot)
public:
  std::unordered_map<EntityId, SequenceEventListCollection*> sequences;
  std::vector<ChangedSequenceTrack> changedTracks;

  SequenceStoreSnapshot();
  ~SequenceStoreSnapshot();

  SequenceStoreSnapshot(const SequenceStoreSnapshot&) = delete;
  SequenceStoreSnapshot(SequenceStoreSnapshot&&) = delete;
  SequenceStoreSnapshot& operator=(const SequenceStoreSnapshot&) = delete;
  SequenceStoreSnapshot& operator=(SequenceStoreSnapshot&&) = delete;

  SequenceStoreSnapshot* clone() const;
  void setSequence(EntityId sequenceId, SequenceEventListCollection* sequence);
  void removeSequence(EntityId sequenceId);
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
class RuntimeSequenceStore {
  friend class RuntimeSequenceStoreTest;
private:
  JUCE_LEAK_DETECTOR(RuntimeSequenceStore)

  // Map of sequence ID to a set of event lists for that sequence.
  SequenceStoreSnapshot* eventLists;

  // The map currently being held by the audio thread. This will be the same as
  // eventLists, except when we are in the process of updating it.
  SequenceStoreSnapshot* rt_eventLists;

  // For sending new values of the map to the audio thread
  RingBuffer<SequenceStoreSnapshot*, 1024> mapUpdateQueue;

  // For the audio thread to send old values of the map to be deleted by the
  // main thread
  RingBuffer<SequenceStoreSnapshot*, 1024> mapDeletionQueue;

  juce::TimedCallback clearDeletionQueueTimedCallback;

  void processDeletionQueues();
public:
  RuntimeSequenceStore();
  ~RuntimeSequenceStore();

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

  // Gets the event list snapshot currently owned by the audio thread.
  SequenceStoreSnapshot& rt_getEventLists();

  // Registers a timer with JUCE that will periodically delete old snapshots
  // that the audio thread has released.
  //
  // This is separate from the constructor so we can not call it in tests.
  void registerDeletionTimer();

  // Adds or updates a sequence in the event lists map.
  //
  // This method is intended to be called from the main thread. It clones the
  // current store snapshot, adds the new sequence, and pushes the new snapshot
  // to the audio thread.
  void addOrUpdateSequence(EntityId sequenceId, const SequenceEventListCollection& sequence);

  // Removes a sequence from the event lists map.
  void removeSequence(EntityId sequenceId);

  // Adds or updates a track in a sequence in the event lists map.
  //
  // This method is intended to be called from the main thread. It clones the
  // current store snapshot, clones only the affected sequence's track snapshot,
  // adds the new track, and pushes the new snapshot to the audio thread.
  void addOrUpdateTrackInSequence(
      EntityId sequenceId, EntityId trackId, const SequenceEventList& track);

  // Removes a track from a sequence in the event lists map.
  void removeTrackFromSequence(EntityId sequenceId, EntityId trackId);

  // Removes every instance of the given track from every sequence.
  void removeTrackFromAllSequences(EntityId trackId);

  // Clears per-block invalidation flags. Must be run at the end of each
  // processing block.
  void rt_cleanupAfterBlock();
};

} // namespace anthem
