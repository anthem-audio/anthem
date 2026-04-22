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

#include "sequence_compiler.h"

#include "modules/core/engine.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <algorithm>

namespace anthem {

void SequenceCompiler::compilePattern(EntityId patternId) {
  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return;
  }

  SequenceEventListCollection newSequence;
  auto* noTrackEvents = new SequenceEventList();

  getPatternNoteEvents(patternId, std::nullopt, std::nullopt, std::nullopt, noTrackEvents->events);
  sortEventList(noTrackEvents->events);

  newSequence.setTrack(sequencer_track_ids::noTrack, noTrackEvents);

  auto& store = *engine.sequenceStore;
  store.addOrUpdateSequence(patternId, newSequence);
}

void SequenceCompiler::compilePattern(EntityId patternId,
    std::vector<EntityId>& trackIdsToRebuild,
    std::vector<std::tuple<double, double>>& invalidationRanges) {
  // When compiling a bare pattern, we put all events into a special "no track"
  // event list. For now, it's not possible for a pattern to contribute events
  // to any other track.
  //
  // This allows us to choose where to send a pattern's events, depending on
  // which track is currently active. If a pattern has multiple clips on
  // multiple different tracks and we double-click on one of them, the active
  // track is set. Then, when the pattern is played in e.g. the piano roll, the
  // active sequence is set to the pattern's sequence, but we are able to choose
  // the correct destination for those events because we know to forward them to
  // the active track.
  //
  // The transport contains the real-time-facing source of truth for the active
  // sequence ID.

  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return;
  }

  bool shouldCompileNoTrackEvents =
      std::find(trackIdsToRebuild.begin(), trackIdsToRebuild.end(), sequencer_track_ids::noTrack) !=
      trackIdsToRebuild.end();

  if (!shouldCompileNoTrackEvents) {
    return;
  }

  SequenceEventList noTrackEvents;
  if (!invalidationRanges.empty()) {
    noTrackEvents.invalidationRanges = invalidationRanges;
  }

  getPatternNoteEvents(patternId, std::nullopt, std::nullopt, std::nullopt, noTrackEvents.events);
  sortEventList(noTrackEvents.events);

  auto& store = *engine.sequenceStore;
  store.addOrUpdateTrackInSequence(patternId, sequencer_track_ids::noTrack, noTrackEvents);
}

void SequenceCompiler::compileArrangement(EntityId arrangementId) {
  auto& engine = Engine::getInstance();

  auto arrangementIter = engine.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == engine.project->sequence()->arrangements()->end()) {
    return;
  }
  auto arrangement = arrangementIter->second;

  // This will leak memory if it's not assigned somewhere or cleaned up here
  SequenceEventListCollection newSequence;

  // For every track, get the note events for that track.
  for (EntityId& trackId : *engine.project->trackOrder()) {
    auto* newChannelEvents = new SequenceEventList();

    getTrackNoteEventsForArrangement(trackId, arrangementId, newChannelEvents->events);
    sortEventList(newChannelEvents->events);

    newSequence.setTrack(trackId, newChannelEvents);
  }

  // Add the new sequence to the store
  auto& store = *engine.sequenceStore;
  store.addOrUpdateSequence(arrangementId, newSequence);
}

void SequenceCompiler::compileArrangement(EntityId arrangementId,
    std::vector<EntityId>& trackIdsToRebuild,
    std::vector<std::tuple<double, double>>& invalidationRanges) {
  auto& store = *Engine::getInstance().sequenceStore;

  for (auto& trackId : trackIdsToRebuild) {
    SequenceEventList newChannelEvents;
    newChannelEvents.invalidationRanges = invalidationRanges;

    getTrackNoteEventsForArrangement(trackId, arrangementId, newChannelEvents.events);
    sortEventList(newChannelEvents.events);

    store.addOrUpdateTrackInSequence(arrangementId, trackId, newChannelEvents);
  }
}

void SequenceCompiler::cleanUpTrack(EntityId trackId) {
  auto& store = *Engine::getInstance().sequenceStore;

  store.removeTrackFromAllSequences(trackId);
}

void SequenceCompiler::getTrackNoteEventsForArrangement(
    EntityId trackId, EntityId arrangementId, std::vector<SequenceEvent>& events) {
  auto& engine = Engine::getInstance();

  auto arrangementIter = engine.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == engine.project->sequence()->arrangements()->end()) {
    return;
  }

  auto& arrangement = arrangementIter->second;

  auto& clips = arrangement->clips();

  for (auto& clipPair : *clips) {
    auto clip = clipPair.second;
    if (clip->trackId() != trackId) {
      continue;
    }

    auto& timeView = clip->timeView();
    getPatternNoteEvents(clip->patternId(),
        clip->id(),
        timeView.has_value()
            ? std::make_optional(std::make_tuple(static_cast<double>((*timeView)->start()),
                  static_cast<double>((*timeView)->end())))
            : std::nullopt,
        static_cast<double>(clip->offset()),
        events);
  }
}

void SequenceCompiler::getPatternNoteEvents(EntityId patternId,
    std::optional<EntityId> clipId,
    std::optional<std::tuple<double, double>> range,
    std::optional<double> offset,
    std::vector<SequenceEvent>& events) {
  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return;
  }

  auto pattern = patternIter->second;

  for (auto& noteEntry : *pattern->notes()) {
    auto note = noteEntry.second;
    auto noteInstanceId = clipId.has_value() ? note_instance_ids::fromArrangementClipNoteId(
                                                   clipId.value(), note->id())
                                             : note_instance_ids::fromPatternNoteId(note->id());
    auto rangeOptional = clampStartAndEndToRange(static_cast<double>(note->offset()),
        static_cast<double>(note->offset() + note->length()),
        range);

    if (!rangeOptional.has_value()) {
      continue;
    }

    auto [start, end] = rangeOptional.value();

    auto startWithOffset = offset.has_value() ? start + offset.value() : start;
    auto endWithOffset = offset.has_value() ? end + offset.value() : end;

    // If a range is specified, then this is for a clip. The events that are
    // output must be relative to the start of the clip. range.start is the
    // start of the clip, so we subtract it from the start and end times.
    if (range.has_value()) {
      startWithOffset = startWithOffset - std::get<0>(range.value());
      endWithOffset = endWithOffset - std::get<0>(range.value());
    }

    events.push_back(SequenceEvent{.offset = startWithOffset,
        .sourceId = noteInstanceId,
        .event = Event(NoteOnEvent(static_cast<int16_t>(note->key()),
            static_cast<int16_t>(0),
            static_cast<float>(note->velocity()),
            0.f))});

    events.push_back(SequenceEvent{.offset = endWithOffset,
        .sourceId = noteInstanceId,
        .event =
            Event(NoteOffEvent(static_cast<int16_t>(note->key()), static_cast<int16_t>(0), 0.f))});
  }
}

void SequenceCompiler::sortEventList(std::vector<SequenceEvent>& events) {
  std::sort(events.begin(), events.end(), [](const SequenceEvent& a, const SequenceEvent& b) {
    if (a.offset != b.offset) {
      return a.offset < b.offset;
    }

    // If the offsets are equal, sort by event type. This allows us to give
    // certain events priority over others - e.g., if a noteOff and a noteOn
    // occur at the same time, the noteOff should come first.
    return a.event.type < b.event.type;
  });
}

std::optional<std::tuple<double, double>> SequenceCompiler::clampStartAndEndToRange(
    double start, double end, std::optional<std::tuple<double, double>> range) {
  if (!range.has_value()) {
    return std::make_tuple(start, end);
  }

  auto [rangeStart, rangeEnd] = range.value();

  if (start < rangeStart && end < rangeStart) {
    return std::nullopt;
  }

  if (start >= rangeEnd && end >= rangeEnd) {
    return std::nullopt;
  }

  return std::make_tuple(
      clampTimeToRange(start, range.value()), clampTimeToRange(end, range.value()));
}

double SequenceCompiler::clampTimeToRange(double time, const std::tuple<double, double>& range) {
  auto [start, end] = range;

  if (time < start) {
    return start;
  }

  if (time > end) {
    return end;
  }

  return time;
}

} // namespace anthem
