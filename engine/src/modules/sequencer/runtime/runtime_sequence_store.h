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

#include "generated/lib/model/pattern/automation_point.h"
#include "modules/sequencer/events/event.h"
#include "modules/util/ring_buffer.h"

#include <cstdint>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <tuple>
#include <unordered_map>
#include <vector>

namespace anthem {

class RuntimeSequenceStoreTest;

namespace sequencer_track_ids {
inline constexpr int64_t noTrack = -1;
}

using EntityId = int64_t;

/*
  Anthem compiles each pattern and arrangement into runtime data for each
  track. For notes, this is a list of sequencer events. For automation, this is
  a list of automation spans. When that pattern or arrangement is updated, its
  runtime data is updated as well. The entire pattern can be updated, or a
  specific track can be surgically replaced.

  The goal of this file is to provide a way to:
    1. Store compiled sequences, either patterns or arrangements
    2. Allow these compiled sequences to be replaced, either in full or in part,
       in a real-time safe way

  The main implementation in this file is RuntimeCompiledSequenceStore. This
  class contains the API that other modules are expected to use through the
  RuntimeSequenceStore and RuntimeAutomationSequenceStore aliases. It is
  responsible for storing the compiled sequences, and managing the process of
  sending new sequences to the audio thread.
*/

// Stores a list of note events meant for a single track.
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

// Stores one compiled automation curve segment.
//
// A sequence provider reads these spans on the audio thread and turns them into
// live control values. Each span stores the visible tick range in the compiled
// sequence, plus enough source-curve information to evaluate clipped curves
// correctly.
struct AutomationSequenceSpan {
  double startTick = 0.0;
  double endTick = 0.0;

  float startValue = 0.0f;
  float endValue = 0.0f;

  AutomationCurveType curve = AutomationCurveType::smooth;
  double tension = 0.0;

  // Normalized positions within the original, uncut source curve segment.
  //
  // In the regular UI-facing project model, automation clips may be cut off.
  // They can cut anywhere, including in the middle of a curve. This means we
  // may have to represent curves that are cut off.
  //
  // The span's startTick and endTick describe where the visible part of the
  // curve lives in the compiled sequence. These normalized values describe
  // which part of the original source curve should be evaluated over that
  // visible span. For example, if a visible clip section runs from 0 to 50 but
  // the source curve segment runs from 0 to 100, startTick/endTick are 0 and
  // 50, while sourceCurveStartNormalized/sourceCurveEndNormalized are 0 and
  // 0.5.
  double sourceCurveStartNormalized = 0.0;
  double sourceCurveEndNormalized = 1.0;
};

// Stores compiled automation spans for a single track.
//
// This mirrors SequenceEventList: both are the per-track compiled payloads
// stored by RuntimeCompiledSequenceStore. There will be at least one of these
// per sequence (pattern or arrangement), unless the sequence is completely
// empty.
class AutomationSpanList {
private:
  JUCE_LEAK_DETECTOR(AutomationSpanList)
public:
  // List of automation spans for this track.
  std::vector<AutomationSequenceSpan> spans;

  // The value that should be used before the first span starts, or as the
  // sequence value when there are no spans.
  bool hasInitialValue = false;
  float initialValue = 0.0f;

  // Automation does not currently use invalidation ranges, but keeping this
  // shape shared lets it use the same runtime store implementation as notes.
  // Automation writers leave this empty, and automation readers ignore
  // rt_invalidationOccurred.
  std::vector<std::tuple<double, double>> invalidationRanges;
  bool rt_invalidationOccurred = false;

  // Number of live track snapshots that reference this automation span list.
  // This is only mutated on the main thread.
  int snapshotRefCount = 0;

  AutomationSpanList();
  AutomationSpanList(const AutomationSpanList& other);
  AutomationSpanList(AutomationSpanList&& other) noexcept;
  AutomationSpanList& operator=(const AutomationSpanList& other);
  AutomationSpanList& operator=(AutomationSpanList&& other) noexcept;

  ~AutomationSpanList() = default;
};

struct ChangedSequenceTrack {
  EntityId sequenceId;
  EntityId trackId;

  // Ranges that should be checked for invalidation when the changed track is
  // published to the audio thread. Notes use this to silence stale events in
  // the current block. Automation currently leaves this empty.
  std::vector<std::tuple<double, double>> invalidationRanges;
};

// Stores a set of compiled track payloads for a given sequence (either pattern
// or arrangement).
template <typename TrackData> class RuntimeSequenceTrackCollection {
private:
  JUCE_LEAK_DETECTOR(RuntimeSequenceTrackCollection)
public:
  // Map of track ID to compiled data for that track. If there is no entry for a
  // given track, it means that there is no compiled data for that track.
  std::unordered_map<EntityId, TrackData*> tracks;

  // Number of live store snapshots that reference this track map. This is only
  // mutated on the main thread.
  int snapshotRefCount = 0;

  RuntimeSequenceTrackCollection();
  ~RuntimeSequenceTrackCollection();

  RuntimeSequenceTrackCollection(const RuntimeSequenceTrackCollection&) = delete;
  RuntimeSequenceTrackCollection(RuntimeSequenceTrackCollection&&) = delete;
  RuntimeSequenceTrackCollection& operator=(const RuntimeSequenceTrackCollection&) = delete;
  RuntimeSequenceTrackCollection& operator=(RuntimeSequenceTrackCollection&&) = delete;

  RuntimeSequenceTrackCollection* clone() const;
  void setTrack(EntityId trackId, TrackData* track);
  void removeTrack(EntityId trackId);
};

template <typename TrackData> class RuntimeSequenceStoreSnapshot {
private:
  JUCE_LEAK_DETECTOR(RuntimeSequenceStoreSnapshot)
public:
  // Map of sequence ID to a set of compiled track data for that sequence.
  std::unordered_map<EntityId, RuntimeSequenceTrackCollection<TrackData>*> sequences;

  // Tracks changed by this snapshot update. The audio thread uses this to mark
  // per-track invalidation state once it receives the snapshot.
  std::vector<ChangedSequenceTrack> changedTracks;

  RuntimeSequenceStoreSnapshot();
  ~RuntimeSequenceStoreSnapshot();

  RuntimeSequenceStoreSnapshot(const RuntimeSequenceStoreSnapshot&) = delete;
  RuntimeSequenceStoreSnapshot(RuntimeSequenceStoreSnapshot&&) = delete;
  RuntimeSequenceStoreSnapshot& operator=(const RuntimeSequenceStoreSnapshot&) = delete;
  RuntimeSequenceStoreSnapshot& operator=(RuntimeSequenceStoreSnapshot&&) = delete;

  RuntimeSequenceStoreSnapshot* clone() const;
  void setSequence(EntityId sequenceId, RuntimeSequenceTrackCollection<TrackData>* sequence);
  void removeSequence(EntityId sequenceId);
};

// This class is responsible for storing sequences for the audio thread, and
// managing the process of sending new sequences to the audio thread.
//
// In Anthem, the sequence model is complex. To manage the complexity with
// respect to the audio thread, we "compile" sequences into per-track runtime
// data. Notes are compiled into time-sorted lists of events. Automation is
// compiled into time-sorted lists of spans. These lists are much easier to deal
// with from the sequencer's perspective. The runtime component of the sequencer
// doesn't even know about patterns - it just sees these compiled lists.
//
// We store compiled track lists for each arrangement and for each pattern. When
// something is changed, e.g. some notes are moved around for a given pattern,
// we don't recompile the entire sequence. Instead, we just update the compiled
// data for the relevant track.
//
// Invalidation support is always present so that note and automation sequences
// can share one store implementation. Automation currently leaves the
// invalidation ranges empty, and its provider ignores the invalidation flag.
template <typename TrackData> class RuntimeCompiledSequenceStore {
  friend class RuntimeSequenceStoreTest;
private:
  JUCE_LEAK_DETECTOR(RuntimeCompiledSequenceStore)

  // Map of sequence ID to a set of compiled track lists for that sequence.
  RuntimeSequenceStoreSnapshot<TrackData>* eventLists;

  // The map currently being held by the audio thread. This will be the same as
  // eventLists, except when we are in the process of updating it.
  RuntimeSequenceStoreSnapshot<TrackData>* rt_eventLists;

  // For sending new values of the map to the audio thread
  RingBuffer<RuntimeSequenceStoreSnapshot<TrackData>*, 1024> mapUpdateQueue;

  // For the audio thread to send old values of the map to be deleted by the
  // main thread
  RingBuffer<RuntimeSequenceStoreSnapshot<TrackData>*, 1024> mapDeletionQueue;

  juce::TimedCallback clearDeletionQueueTimedCallback;

  void processDeletionQueues();
public:
  RuntimeCompiledSequenceStore();
  ~RuntimeCompiledSequenceStore();

  // Picks up any updates to the compiled sequence map from the mapUpdateQueue.
  //
  // Must be run at the start of each processing block.
  void rt_processSequenceChanges(int bufferSize);

  // Gets a compiled sequence view on the main thread.
  //
  // This returns the current main-thread snapshot of the compiled per-track
  // data.
  // Callers must not hold onto the returned pointer across unrelated sequence
  // store updates.
  const RuntimeSequenceTrackCollection<TrackData>* getSequenceEventList(EntityId sequenceId) const;

  // Gets a compiled sequence view on the main thread.
  //
  // This is the same API as getSequenceEventList(), but named for callers that
  // read non-event compiled sequence data such as automation spans.
  const RuntimeSequenceTrackCollection<TrackData>* getSequence(EntityId sequenceId) const;

  // Gets the compiled sequence snapshot currently owned by the audio thread.
  RuntimeSequenceStoreSnapshot<TrackData>& rt_getEventLists();

  // Gets the compiled sequence snapshot currently owned by the audio thread.
  //
  // This is the same API as rt_getEventLists(), but named for callers that read
  // non-event compiled sequence data such as automation spans.
  RuntimeSequenceStoreSnapshot<TrackData>& rt_getSequences();

  // Registers a timer with JUCE that will periodically delete old snapshots
  // that the audio thread has released.
  //
  // This is separate from the constructor so we can not call it in tests.
  void registerDeletionTimer();

  // Adds or updates a sequence in the compiled sequence map.
  //
  // This method is intended to be called from the main thread. It clones the
  // current store snapshot, adds the new sequence, and pushes the new snapshot
  // to the audio thread.
  void addOrUpdateSequence(
      EntityId sequenceId, const RuntimeSequenceTrackCollection<TrackData>& sequence);

  // Removes a sequence from the compiled sequence map.
  void removeSequence(EntityId sequenceId);

  // Adds or updates a track in a sequence in the compiled sequence map.
  //
  // This method is intended to be called from the main thread. It clones the
  // current store snapshot, clones only the affected sequence's track snapshot,
  // adds the new track, and pushes the new snapshot to the audio thread.
  void addOrUpdateTrackInSequence(EntityId sequenceId, EntityId trackId, const TrackData& track);

  // Removes a track from a sequence in the compiled sequence map.
  void removeTrackFromSequence(EntityId sequenceId, EntityId trackId);

  // Removes every instance of the given track from every sequence.
  void removeTrackFromAllSequences(EntityId trackId);

  // Clears per-block invalidation flags. Must be run at the end of each
  // processing block for stores whose readers consume invalidation flags.
  void rt_cleanupAfterBlock();
};

using SequenceEventListCollection = RuntimeSequenceTrackCollection<SequenceEventList>;
using SequenceStoreSnapshot = RuntimeSequenceStoreSnapshot<SequenceEventList>;
using RuntimeSequenceStore = RuntimeCompiledSequenceStore<SequenceEventList>;

using AutomationSpanListCollection = RuntimeSequenceTrackCollection<AutomationSpanList>;
using AutomationSequenceStoreSnapshot = RuntimeSequenceStoreSnapshot<AutomationSpanList>;
using RuntimeAutomationSequenceStore = RuntimeCompiledSequenceStore<AutomationSpanList>;

} // namespace anthem
