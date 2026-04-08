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

#include "modules/core/anthem.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <algorithm>

void AnthemSequenceCompiler::compilePattern(EntityId patternId) {
  auto& anthem = Anthem::getInstance();

  auto patternIter = anthem.project->sequence()->patterns()->find(patternId);
  if (patternIter == anthem.project->sequence()->patterns()->end()) {
    return;
  }

  SequenceEventListCollection newSequence;
  SequenceEventList noTrackEvents;

  getPatternNoteEvents(patternId, std::nullopt, std::nullopt, std::nullopt, *noTrackEvents.events);
  sortEventList(*noTrackEvents.events);

  newSequence.tracks->insert_or_assign(
      anthem_sequencer_track_ids::noTrack, std::move(noTrackEvents));

  auto& store = *anthem.sequenceStore;
  store.addOrUpdateSequence(patternId, newSequence);
}

void AnthemSequenceCompiler::compilePattern(EntityId patternId,
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

  auto& anthem = Anthem::getInstance();

  auto patternIter = anthem.project->sequence()->patterns()->find(patternId);
  if (patternIter == anthem.project->sequence()->patterns()->end()) {
    return;
  }

  bool shouldCompileNoTrackEvents =
      std::find(trackIdsToRebuild.begin(),
          trackIdsToRebuild.end(),
          anthem_sequencer_track_ids::noTrack) != trackIdsToRebuild.end();

  if (!shouldCompileNoTrackEvents) {
    return;
  }

  SequenceEventList noTrackEvents;
  if (!invalidationRanges.empty()) {
    noTrackEvents.invalidationRanges =
        new std::vector<std::tuple<double, double>>(invalidationRanges);
  }

  getPatternNoteEvents(patternId, std::nullopt, std::nullopt, std::nullopt, *noTrackEvents.events);
  sortEventList(*noTrackEvents.events);

  auto& store = *anthem.sequenceStore;
  store.addOrUpdateTrackInSequence(patternId, anthem_sequencer_track_ids::noTrack, noTrackEvents);
}

void AnthemSequenceCompiler::compileArrangement(EntityId arrangementId) {
  auto& anthem = Anthem::getInstance();

  auto arrangementIter = anthem.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == anthem.project->sequence()->arrangements()->end()) {
    return;
  }
  auto arrangement = arrangementIter->second;

  // This will leak memory if it's not assigned somewhere or cleaned up here
  SequenceEventListCollection newSequence;

  // For every track, get the note events for that track.
  for (EntityId& trackId : *anthem.project->trackOrder()) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;

    getTrackNoteEventsForArrangement(trackId, arrangementId, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    newSequence.tracks->insert_or_assign(trackId, std::move(newChannelEvents));
  }

  // Add the new sequence to the store
  auto& store = *anthem.sequenceStore;
  store.addOrUpdateSequence(arrangementId, newSequence);
}

void AnthemSequenceCompiler::compileArrangement(EntityId arrangementId,
    std::vector<EntityId>& trackIdsToRebuild,
    std::vector<std::tuple<double, double>>& invalidationRanges) {
  auto& store = *Anthem::getInstance().sequenceStore;

  for (auto& trackId : trackIdsToRebuild) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;
    newChannelEvents.invalidationRanges =
        new std::vector<std::tuple<double, double>>(invalidationRanges);

    getTrackNoteEventsForArrangement(trackId, arrangementId, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    store.addOrUpdateTrackInSequence(arrangementId, trackId, newChannelEvents);
  }
}

void AnthemSequenceCompiler::cleanUpTrack(EntityId trackId) {
  auto& store = *Anthem::getInstance().sequenceStore;

  store.removeTrackFromAllSequences(trackId);
}

void AnthemSequenceCompiler::getTrackNoteEventsForArrangement(
    EntityId trackId, EntityId arrangementId, std::vector<AnthemSequenceEvent>& events) {
  auto& anthem = Anthem::getInstance();

  auto arrangementIter = anthem.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == anthem.project->sequence()->arrangements()->end()) {
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

void AnthemSequenceCompiler::getPatternNoteEvents(EntityId patternId,
    std::optional<EntityId> clipId,
    std::optional<std::tuple<double, double>> range,
    std::optional<double> offset,
    std::vector<AnthemSequenceEvent>& events) {
  auto& anthem = Anthem::getInstance();

  auto patternIter = anthem.project->sequence()->patterns()->find(patternId);
  if (patternIter == anthem.project->sequence()->patterns()->end()) {
    return;
  }

  auto pattern = patternIter->second;

  for (auto& noteEntry : *pattern->notes()) {
    auto note = noteEntry.second;
    auto noteInstanceId =
        clipId.has_value()
            ? anthem_note_instance_ids::fromArrangementClipNoteId(clipId.value(), note->id())
            : anthem_note_instance_ids::fromPatternNoteId(note->id());
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

    events.push_back(AnthemSequenceEvent{.offset = startWithOffset,
        .sourceId = noteInstanceId,
        .event = AnthemEvent(AnthemNoteOnEvent(static_cast<int16_t>(note->key()),
            static_cast<int16_t>(0),
            static_cast<float>(note->velocity()),
            0.f))});

    events.push_back(AnthemSequenceEvent{.offset = endWithOffset,
        .sourceId = noteInstanceId,
        .event = AnthemEvent(
            AnthemNoteOffEvent(static_cast<int16_t>(note->key()), static_cast<int16_t>(0), 0.f))});
  }
}

void AnthemSequenceCompiler::sortEventList(std::vector<AnthemSequenceEvent>& events) {
  std::sort(
      events.begin(), events.end(), [](const AnthemSequenceEvent& a, const AnthemSequenceEvent& b) {
        if (a.offset != b.offset) {
          return a.offset < b.offset;
        }

        // If the offsets are equal, sort by event type. This allows us to give
        // certain events priority over others - e.g., if a noteOff and a noteOn
        // occur at the same time, the noteOff should come first.
        return a.event.type < b.event.type;
      });
}

std::optional<std::tuple<double, double>> AnthemSequenceCompiler::clampStartAndEndToRange(
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

double AnthemSequenceCompiler::clampTimeToRange(
    double time, const std::tuple<double, double>& range) {
  auto [start, end] = range;

  if (time < start) {
    return start;
  }

  if (time > end) {
    return end;
  }

  return time;
}
