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

#include "runtime_sequence_store.h"

#include "modules/core/engine.h"
#include "modules/util/intentionally_leak.h"

#include <algorithm>

namespace anthem {

namespace {
template <typename TrackData> void retain(TrackData* track) {
  if (track != nullptr) {
    track->snapshotRefCount++;
  }
}

template <typename TrackData> void release(TrackData* track) {
  if (track == nullptr) {
    return;
  }

  jassert(track->snapshotRefCount > 0);
  track->snapshotRefCount--;

  if (track->snapshotRefCount == 0) {
    delete track;
  }
}

template <typename TrackData> void retain(RuntimeSequenceTrackCollection<TrackData>* sequence) {
  if (sequence != nullptr) {
    sequence->snapshotRefCount++;
  }
}

template <typename TrackData> void release(RuntimeSequenceTrackCollection<TrackData>* sequence) {
  if (sequence == nullptr) {
    return;
  }

  jassert(sequence->snapshotRefCount > 0);
  sequence->snapshotRefCount--;

  if (sequence->snapshotRefCount == 0) {
    delete sequence;
  }
}

bool rt_hasInvalidationForCurrentBlock(
    const std::vector<std::tuple<double, double>>& invalidationRanges,
    double playheadStart,
    double playheadEnd,
    double loopStartRangeBegin,
    double loopStartRangeEnd) {
  for (const auto& range : invalidationRanges) {
    const bool isWithinMainRange =
        playheadStart <= std::get<1>(range) && playheadEnd >= std::get<0>(range);
    const bool isWithinLoopRange =
        loopStartRangeBegin != -1.0 &&
        (loopStartRangeBegin <= std::get<1>(range) && loopStartRangeEnd >= std::get<0>(range));

    if (isWithinMainRange || isWithinLoopRange) {
      return true;
    }
  }

  return false;
}

template <typename TrackData>
void rt_applyChangedTrackInvalidation(RuntimeSequenceStoreSnapshot<TrackData>& snapshot,
    const ChangedSequenceTrack& changedTrack,
    double playheadStart,
    double playheadEnd,
    double loopStartRangeBegin,
    double loopStartRangeEnd) {
  if (!rt_hasInvalidationForCurrentBlock(changedTrack.invalidationRanges,
          playheadStart,
          playheadEnd,
          loopStartRangeBegin,
          loopStartRangeEnd)) {
    return;
  }

  auto sequenceIter = snapshot.sequences.find(changedTrack.sequenceId);
  if (sequenceIter == snapshot.sequences.end()) {
    return;
  }

  auto* sequence = sequenceIter->second;
  auto trackIter = sequence->tracks.find(changedTrack.trackId);
  if (trackIter == sequence->tracks.end()) {
    return;
  }

  trackIter->second->rt_invalidationOccurred = true;
}

template <typename TrackData>
bool publishSnapshot(RingBuffer<RuntimeSequenceStoreSnapshot<TrackData>*, 1024>& queue,
    RuntimeSequenceStoreSnapshot<TrackData>*& currentSnapshot,
    RuntimeSequenceStoreSnapshot<TrackData>* newSnapshot) {
  if (!queue.add(newSnapshot)) {
    jassertfalse;
    delete newSnapshot;
    return false;
  }

  currentSnapshot = newSnapshot;
  return true;
}

template <typename TrackData>
void addSnapshotForDeletion(std::vector<RuntimeSequenceStoreSnapshot<TrackData>*>& snapshots,
    RuntimeSequenceStoreSnapshot<TrackData>* snapshot) {
  if (snapshot == nullptr) {
    return;
  }

  if (std::find(snapshots.begin(), snapshots.end(), snapshot) == snapshots.end()) {
    snapshots.push_back(snapshot);
  }
}
} // namespace

SequenceEventList::SequenceEventList() = default;

SequenceEventList::SequenceEventList(const SequenceEventList& other)
  : events(other.events), invalidationRanges(other.invalidationRanges),
    rt_invalidationOccurred(other.rt_invalidationOccurred) {}

SequenceEventList::SequenceEventList(SequenceEventList&& other) noexcept
  : events(std::move(other.events)), invalidationRanges(std::move(other.invalidationRanges)),
    rt_invalidationOccurred(other.rt_invalidationOccurred) {
  other.rt_invalidationOccurred = false;
}

SequenceEventList& SequenceEventList::operator=(const SequenceEventList& other) {
  jassert(snapshotRefCount == 0);
  events = other.events;
  invalidationRanges = other.invalidationRanges;
  rt_invalidationOccurred = other.rt_invalidationOccurred;
  return *this;
}

SequenceEventList& SequenceEventList::operator=(SequenceEventList&& other) noexcept {
  jassert(snapshotRefCount == 0);
  events = std::move(other.events);
  invalidationRanges = std::move(other.invalidationRanges);
  rt_invalidationOccurred = other.rt_invalidationOccurred;
  other.rt_invalidationOccurred = false;
  return *this;
}

AutomationSpanList::AutomationSpanList() = default;

AutomationSpanList::AutomationSpanList(const AutomationSpanList& other)
  : spans(other.spans), hasInitialValue(other.hasInitialValue), initialValue(other.initialValue),
    invalidationRanges(other.invalidationRanges),
    rt_invalidationOccurred(other.rt_invalidationOccurred) {}

AutomationSpanList::AutomationSpanList(AutomationSpanList&& other) noexcept
  : spans(std::move(other.spans)), hasInitialValue(other.hasInitialValue),
    initialValue(other.initialValue), invalidationRanges(std::move(other.invalidationRanges)),
    rt_invalidationOccurred(other.rt_invalidationOccurred) {
  other.hasInitialValue = false;
  other.initialValue = 0.0f;
  other.rt_invalidationOccurred = false;
}

AutomationSpanList& AutomationSpanList::operator=(const AutomationSpanList& other) {
  jassert(snapshotRefCount == 0);
  spans = other.spans;
  hasInitialValue = other.hasInitialValue;
  initialValue = other.initialValue;
  invalidationRanges = other.invalidationRanges;
  rt_invalidationOccurred = other.rt_invalidationOccurred;
  return *this;
}

AutomationSpanList& AutomationSpanList::operator=(AutomationSpanList&& other) noexcept {
  jassert(snapshotRefCount == 0);
  spans = std::move(other.spans);
  hasInitialValue = other.hasInitialValue;
  initialValue = other.initialValue;
  invalidationRanges = std::move(other.invalidationRanges);
  rt_invalidationOccurred = other.rt_invalidationOccurred;
  other.hasInitialValue = false;
  other.initialValue = 0.0f;
  other.rt_invalidationOccurred = false;
  return *this;
}

template <typename TrackData>
RuntimeSequenceTrackCollection<TrackData>::RuntimeSequenceTrackCollection() = default;

template <typename TrackData>
RuntimeSequenceTrackCollection<TrackData>::~RuntimeSequenceTrackCollection() {
  for (auto& [trackId, track] : tracks) {
    release(track);
  }
}

template <typename TrackData>
RuntimeSequenceTrackCollection<TrackData>*
RuntimeSequenceTrackCollection<TrackData>::clone() const {
  auto* result = new RuntimeSequenceTrackCollection<TrackData>();

  for (auto& [trackId, track] : tracks) {
    result->setTrack(trackId, track);
  }

  return result;
}

template <typename TrackData>
void RuntimeSequenceTrackCollection<TrackData>::setTrack(EntityId trackId, TrackData* track) {
  retain(track);

  auto existingTrack = tracks.find(trackId);
  if (existingTrack != tracks.end()) {
    release(existingTrack->second);
    existingTrack->second = track;
    return;
  }

  tracks.insert_or_assign(trackId, track);
}

template <typename TrackData>
void RuntimeSequenceTrackCollection<TrackData>::removeTrack(EntityId trackId) {
  auto existingTrack = tracks.find(trackId);
  if (existingTrack == tracks.end()) {
    return;
  }

  release(existingTrack->second);
  tracks.erase(existingTrack);
}

template <typename TrackData>
RuntimeSequenceStoreSnapshot<TrackData>::RuntimeSequenceStoreSnapshot() = default;

template <typename TrackData>
RuntimeSequenceStoreSnapshot<TrackData>::~RuntimeSequenceStoreSnapshot() {
  for (auto& [sequenceId, sequence] : sequences) {
    release(sequence);
  }
}

template <typename TrackData>
RuntimeSequenceStoreSnapshot<TrackData>* RuntimeSequenceStoreSnapshot<TrackData>::clone() const {
  auto* result = new RuntimeSequenceStoreSnapshot<TrackData>();

  for (auto& [sequenceId, sequence] : sequences) {
    result->setSequence(sequenceId, sequence);
  }

  result->changedTracks = changedTracks;

  return result;
}

template <typename TrackData>
void RuntimeSequenceStoreSnapshot<TrackData>::setSequence(
    EntityId sequenceId, RuntimeSequenceTrackCollection<TrackData>* sequence) {
  retain(sequence);

  auto existingSequence = sequences.find(sequenceId);
  if (existingSequence != sequences.end()) {
    release(existingSequence->second);
    existingSequence->second = sequence;
    return;
  }

  sequences.insert_or_assign(sequenceId, sequence);
}

template <typename TrackData>
void RuntimeSequenceStoreSnapshot<TrackData>::removeSequence(EntityId sequenceId) {
  auto existingSequence = sequences.find(sequenceId);
  if (existingSequence == sequences.end()) {
    return;
  }

  release(existingSequence->second);
  sequences.erase(existingSequence);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::rt_processSequenceChanges(int bufferSize) {
  auto result = mapUpdateQueue.read();

  double playheadStart = -1; // inclusive
  double playheadEnd = -1;   // not inclusive

  // If this block includes a loop jump, these will be set to something besides
  // -1. These represent a range starting at the loop start and extending for
  // the total distance that the playhead will advance this block. If there is a
  // jump, then this will usually be past the playhead's actual end position.
  // The playhead will never go past loopStartRangeEnd in this block.
  double loopStartRangeBegin = -1;
  double loopStartRangeEnd = -1;
  bool hasInvalidationWindow = false;

  auto ensureInvalidationWindow = [&]() {
    if (hasInvalidationWindow) {
      return;
    }

    auto& transport = *Engine::getInstance().transport;
    const double advanceAmount = transport.rt_getPlayheadAdvanceAmount(bufferSize);
    playheadStart = transport.rt_playhead;
    playheadEnd = playheadStart + advanceAmount;

    if (playheadEnd >= transport.rt_config->loopEnd) {
      loopStartRangeBegin = transport.rt_config->loopStart;
      loopStartRangeEnd = loopStartRangeBegin + advanceAmount;
    }

    hasInvalidationWindow = true;
  };

  while (result.has_value()) {
    auto* newSnapshot = result.value();

    if (!newSnapshot->changedTracks.empty()) {
      ensureInvalidationWindow();

      for (auto& changedTrack : newSnapshot->changedTracks) {
        rt_applyChangedTrackInvalidation(*newSnapshot,
            changedTrack,
            playheadStart,
            playheadEnd,
            loopStartRangeBegin,
            loopStartRangeEnd);
      }
    }

    auto* oldSnapshot = rt_eventLists;
    rt_eventLists = newSnapshot;

    if (!mapDeletionQueue.add(oldSnapshot)) {
      intentionallyLeak(oldSnapshot);
    }

    result = mapUpdateQueue.read();
  }
}

template <typename TrackData>
const RuntimeSequenceTrackCollection<TrackData>*
RuntimeCompiledSequenceStore<TrackData>::getSequenceEventList(EntityId sequenceId) const {
  auto iter = eventLists->sequences.find(sequenceId);
  if (iter == eventLists->sequences.end()) {
    return nullptr;
  }

  return iter->second;
}

template <typename TrackData>
const RuntimeSequenceTrackCollection<TrackData>*
RuntimeCompiledSequenceStore<TrackData>::getSequence(EntityId sequenceId) const {
  return getSequenceEventList(sequenceId);
}

template <typename TrackData>
RuntimeSequenceStoreSnapshot<TrackData>&
RuntimeCompiledSequenceStore<TrackData>::rt_getEventLists() {
  return *rt_eventLists;
}

template <typename TrackData>
RuntimeSequenceStoreSnapshot<TrackData>&
RuntimeCompiledSequenceStore<TrackData>::rt_getSequences() {
  return rt_getEventLists();
}

template <typename TrackData>
RuntimeCompiledSequenceStore<TrackData>::RuntimeCompiledSequenceStore()
  : clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->processDeletionQueues(); })) {
  eventLists = new RuntimeSequenceStoreSnapshot<TrackData>();
  rt_eventLists = eventLists;
}

// The audio thread must be stopped before destruction. This drains handoff
// queues and deletes both main-thread and audio-thread snapshots.
template <typename TrackData>
RuntimeCompiledSequenceStore<TrackData>::~RuntimeCompiledSequenceStore() {
  clearDeletionQueueTimedCallback.stopTimer();

  processDeletionQueues();

  auto snapshotsToDelete = std::vector<RuntimeSequenceStoreSnapshot<TrackData>*>();

  while (auto pendingSnapshot = mapUpdateQueue.read()) {
    addSnapshotForDeletion(snapshotsToDelete, pendingSnapshot.value());
  }

  while (auto retiredSnapshot = mapDeletionQueue.read()) {
    addSnapshotForDeletion(snapshotsToDelete, retiredSnapshot.value());
  }

  addSnapshotForDeletion(snapshotsToDelete, eventLists);
  addSnapshotForDeletion(snapshotsToDelete, rt_eventLists);

  for (auto* snapshot : snapshotsToDelete) {
    delete snapshot;
  }

  eventLists = nullptr;
  rt_eventLists = nullptr;
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::processDeletionQueues() {
  auto nextSnapshot = mapDeletionQueue.read();

  while (nextSnapshot.has_value()) {
    delete nextSnapshot.value();
    nextSnapshot = mapDeletionQueue.read();
  }
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::registerDeletionTimer() {
  clearDeletionQueueTimedCallback.startTimer(500);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::addOrUpdateSequence(
    EntityId sequenceId, const RuntimeSequenceTrackCollection<TrackData>& sequence) {
  auto* newSnapshot = eventLists->clone();
  auto* newSequence = sequence.clone();

  newSnapshot->setSequence(sequenceId, newSequence);

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::removeSequence(EntityId sequenceId) {
  if (eventLists->sequences.find(sequenceId) == eventLists->sequences.end()) {
    return;
  }

  auto* newSnapshot = eventLists->clone();
  newSnapshot->removeSequence(sequenceId);

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::addOrUpdateTrackInSequence(
    EntityId sequenceId, EntityId trackId, const TrackData& track) {
  auto* newSnapshot = eventLists->clone();

  auto oldSequenceIter = eventLists->sequences.find(sequenceId);
  auto* newSequence = oldSequenceIter != eventLists->sequences.end()
                          ? oldSequenceIter->second->clone()
                          : new RuntimeSequenceTrackCollection<TrackData>();

  newSequence->setTrack(trackId, new TrackData(track));
  newSnapshot->setSequence(sequenceId, newSequence);

  if (!track.invalidationRanges.empty()) {
    newSnapshot->changedTracks.push_back(ChangedSequenceTrack{
        .sequenceId = sequenceId,
        .trackId = trackId,
        .invalidationRanges = track.invalidationRanges,
    });
  }

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::removeTrackFromSequence(
    EntityId sequenceId, EntityId trackId) {
  auto sequenceIter = eventLists->sequences.find(sequenceId);
  if (sequenceIter == eventLists->sequences.end()) {
    return;
  }

  if (sequenceIter->second->tracks.find(trackId) == sequenceIter->second->tracks.end()) {
    return;
  }

  auto* newSnapshot = eventLists->clone();
  auto* newSequence = sequenceIter->second->clone();
  newSequence->removeTrack(trackId);
  newSnapshot->setSequence(sequenceId, newSequence);

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

template <typename TrackData>
void RuntimeCompiledSequenceStore<TrackData>::removeTrackFromAllSequences(EntityId trackId) {
  auto* newSnapshot = eventLists->clone();

  for (auto& [sequenceId, sequence] : eventLists->sequences) {
    if (sequence->tracks.find(trackId) == sequence->tracks.end()) {
      continue;
    }

    auto* newSequence = sequence->clone();
    newSequence->removeTrack(trackId);
    newSnapshot->setSequence(sequenceId, newSequence);
  }

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

template <typename TrackData> void RuntimeCompiledSequenceStore<TrackData>::rt_cleanupAfterBlock() {
  for (auto& [sequenceId, sequence] : rt_eventLists->sequences) {
    for (auto& [trackId, trackData] : sequence->tracks) {
      trackData->rt_invalidationOccurred = false;
    }
  }
}

template class RuntimeSequenceTrackCollection<SequenceEventList>;
template class RuntimeSequenceTrackCollection<AutomationSpanList>;
template class RuntimeSequenceStoreSnapshot<SequenceEventList>;
template class RuntimeSequenceStoreSnapshot<AutomationSpanList>;
template class RuntimeCompiledSequenceStore<SequenceEventList>;
template class RuntimeCompiledSequenceStore<AutomationSpanList>;

} // namespace anthem
