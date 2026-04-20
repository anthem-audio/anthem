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

#include "modules/core/anthem.h"
#include "modules/util/intentionally_leak.h"

#include <algorithm>

namespace anthem {

namespace {
void retain(SequenceEventList* track) {
  if (track != nullptr) {
    track->snapshotRefCount++;
  }
}

void release(SequenceEventList* track) {
  if (track == nullptr) {
    return;
  }

  jassert(track->snapshotRefCount > 0);
  track->snapshotRefCount--;

  if (track->snapshotRefCount == 0) {
    delete track;
  }
}

void retain(SequenceEventListCollection* sequence) {
  if (sequence != nullptr) {
    sequence->snapshotRefCount++;
  }
}

void release(SequenceEventListCollection* sequence) {
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

void rt_applyChangedTrackInvalidation(SequenceStoreSnapshot& snapshot,
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

bool publishSnapshot(RingBuffer<SequenceStoreSnapshot*, 1024>& queue,
    SequenceStoreSnapshot*& currentSnapshot,
    SequenceStoreSnapshot* newSnapshot) {
  if (!queue.add(newSnapshot)) {
    jassertfalse;
    delete newSnapshot;
    return false;
  }

  currentSnapshot = newSnapshot;
  return true;
}

void addSnapshotForDeletion(
    std::vector<SequenceStoreSnapshot*>& snapshots, SequenceStoreSnapshot* snapshot) {
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

SequenceEventListCollection::SequenceEventListCollection() = default;

SequenceEventListCollection::~SequenceEventListCollection() {
  for (auto& [trackId, track] : tracks) {
    release(track);
  }
}

SequenceEventListCollection* SequenceEventListCollection::clone() const {
  auto* result = new SequenceEventListCollection();

  for (auto& [trackId, track] : tracks) {
    result->setTrack(trackId, track);
  }

  return result;
}

void SequenceEventListCollection::setTrack(EntityId trackId, SequenceEventList* track) {
  retain(track);

  auto existingTrack = tracks.find(trackId);
  if (existingTrack != tracks.end()) {
    release(existingTrack->second);
    existingTrack->second = track;
    return;
  }

  tracks.insert_or_assign(trackId, track);
}

void SequenceEventListCollection::removeTrack(EntityId trackId) {
  auto existingTrack = tracks.find(trackId);
  if (existingTrack == tracks.end()) {
    return;
  }

  release(existingTrack->second);
  tracks.erase(existingTrack);
}

SequenceStoreSnapshot::SequenceStoreSnapshot() = default;

SequenceStoreSnapshot::~SequenceStoreSnapshot() {
  for (auto& [sequenceId, sequence] : sequences) {
    release(sequence);
  }
}

SequenceStoreSnapshot* SequenceStoreSnapshot::clone() const {
  auto* result = new SequenceStoreSnapshot();

  for (auto& [sequenceId, sequence] : sequences) {
    result->setSequence(sequenceId, sequence);
  }

  result->changedTracks = changedTracks;

  return result;
}

void SequenceStoreSnapshot::setSequence(
    EntityId sequenceId, SequenceEventListCollection* sequence) {
  retain(sequence);

  auto existingSequence = sequences.find(sequenceId);
  if (existingSequence != sequences.end()) {
    release(existingSequence->second);
    existingSequence->second = sequence;
    return;
  }

  sequences.insert_or_assign(sequenceId, sequence);
}

void SequenceStoreSnapshot::removeSequence(EntityId sequenceId) {
  auto existingSequence = sequences.find(sequenceId);
  if (existingSequence == sequences.end()) {
    return;
  }

  release(existingSequence->second);
  sequences.erase(existingSequence);
}

void RuntimeSequenceStore::rt_processSequenceChanges(int bufferSize) {
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

  if (result.has_value()) {
    auto& transport = *Engine::getInstance().transport;
    double advanceAmount = transport.rt_getPlayheadAdvanceAmount(bufferSize);
    playheadStart = transport.rt_playhead;
    playheadEnd = playheadStart + advanceAmount;

    if (playheadEnd >= transport.rt_config->loopEnd) {
      loopStartRangeBegin = transport.rt_config->loopStart;
      loopStartRangeEnd = loopStartRangeBegin + advanceAmount;
    }
  }

  while (result.has_value()) {
    auto* newSnapshot = result.value();

    for (auto& changedTrack : newSnapshot->changedTracks) {
      rt_applyChangedTrackInvalidation(*newSnapshot,
          changedTrack,
          playheadStart,
          playheadEnd,
          loopStartRangeBegin,
          loopStartRangeEnd);
    }

    auto* oldSnapshot = rt_eventLists;
    rt_eventLists = newSnapshot;

    if (!mapDeletionQueue.add(oldSnapshot)) {
      intentionallyLeak(oldSnapshot);
    }

    result = mapUpdateQueue.read();
  }
}

const SequenceEventListCollection* RuntimeSequenceStore::getSequenceEventList(
    EntityId sequenceId) const {
  auto it = eventLists->sequences.find(sequenceId);
  if (it == eventLists->sequences.end()) {
    return nullptr;
  }

  return it->second;
}

SequenceStoreSnapshot& RuntimeSequenceStore::rt_getEventLists() {
  return *rt_eventLists;
}

RuntimeSequenceStore::RuntimeSequenceStore()
  : clearDeletionQueueTimedCallback(
        juce::TimedCallback([this]() { this->processDeletionQueues(); })) {
  eventLists = new SequenceStoreSnapshot();
  rt_eventLists = eventLists;
}

// The audio thread must be stopped before destruction. This drains handoff
// queues and deletes both main-thread and audio-thread snapshots.
RuntimeSequenceStore::~RuntimeSequenceStore() {
  clearDeletionQueueTimedCallback.stopTimer();

  processDeletionQueues();

  auto snapshotsToDelete = std::vector<SequenceStoreSnapshot*>();

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

void RuntimeSequenceStore::processDeletionQueues() {
  auto nextSnapshot = mapDeletionQueue.read();

  while (nextSnapshot.has_value()) {
    delete nextSnapshot.value();
    nextSnapshot = mapDeletionQueue.read();
  }
}

void RuntimeSequenceStore::registerDeletionTimer() {
  clearDeletionQueueTimedCallback.startTimer(500);
}

void RuntimeSequenceStore::addOrUpdateSequence(
    EntityId sequenceId, const SequenceEventListCollection& sequence) {
  auto* newSnapshot = eventLists->clone();
  auto* newSequence = sequence.clone();

  newSnapshot->setSequence(sequenceId, newSequence);

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

void RuntimeSequenceStore::removeSequence(EntityId sequenceId) {
  if (eventLists->sequences.find(sequenceId) == eventLists->sequences.end()) {
    return;
  }

  auto* newSnapshot = eventLists->clone();
  newSnapshot->removeSequence(sequenceId);

  publishSnapshot(mapUpdateQueue, eventLists, newSnapshot);
}

void RuntimeSequenceStore::addOrUpdateTrackInSequence(
    EntityId sequenceId, EntityId trackId, const SequenceEventList& track) {
  auto* newSnapshot = eventLists->clone();

  auto oldSequenceIter = eventLists->sequences.find(sequenceId);
  auto* newSequence = oldSequenceIter != eventLists->sequences.end()
                          ? oldSequenceIter->second->clone()
                          : new SequenceEventListCollection();

  newSequence->setTrack(trackId, new SequenceEventList(track));
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

void RuntimeSequenceStore::removeTrackFromSequence(EntityId sequenceId, EntityId trackId) {
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

void RuntimeSequenceStore::removeTrackFromAllSequences(EntityId trackId) {
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

void RuntimeSequenceStore::rt_cleanupAfterBlock() {
  for (auto& [sequenceId, sequence] : rt_eventLists->sequences) {
    for (auto& [trackId, trackEvents] : sequence->tracks) {
      trackEvents->rt_invalidationOccurred = false;
    }
  }
}

} // namespace anthem
