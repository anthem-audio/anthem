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

#include "sequence_compiler.h"
#include "modules/core/anthem.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <algorithm>

void AnthemSequenceCompiler::compilePattern(std::string patternId) {
  auto& anthem = Anthem::getInstance();

  auto patternIter = anthem.project->sequence()->patterns()->find(patternId);
  if (patternIter == anthem.project->sequence()->patterns()->end()) {
    return;
  }
  auto pattern = patternIter->second;
  
  // This will leak memory if it's not assigned somewhere or cleaned up here
  SequenceEventListCollection newSequence;
  
  // For every channel, get the note events for that channel
  for (std::string& channelId : *anthem.project->generatorOrder()) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;

    getChannelNoteEventsForPattern(channelId, patternId, std::nullopt, std::nullopt, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    if (newChannelEvents.events->size() > 0) {
      newSequence.channels->insert_or_assign(channelId, std::move(newChannelEvents));
    }
    else {
      SequenceEventList::cleanUpInstance(newChannelEvents);
    }
  }

  // Add the new sequence to the store
  auto& store = *anthem.sequenceStore;
  store.addOrUpdateSequence(patternId, newSequence);
}

void AnthemSequenceCompiler::compilePattern(
  std::string patternId,
  std::vector<std::string>& channelIdsToRebuild
) {
  auto& store = *Anthem::getInstance().sequenceStore;

  for (auto& channelId : channelIdsToRebuild) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;

    getChannelNoteEventsForPattern(channelId, patternId, std::nullopt, std::nullopt, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    if (newChannelEvents.events->size() > 0) {
      store.addOrUpdateChannelInSequence(patternId, channelId, newChannelEvents);
    }
    else {
      // Just in case, we'll remove the channel from the sequence store. If the
      // channel used to have events and now doesn't, we want to remove it, and
      // if the channel doesn't exist in the pattern then this will be a no-op.
      store.removeChannelFromSequence(patternId, channelId);

      SequenceEventList::cleanUpInstance(newChannelEvents);
    }
  }
}

void AnthemSequenceCompiler::compileArrangement(std::string arrangementId) {
  auto& anthem = Anthem::getInstance();

  auto arrangementIter = anthem.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == anthem.project->sequence()->arrangements()->end()) {
    return;
  }
  auto arrangement = arrangementIter->second;

  // This will leak memory if it's not assigned somewhere or cleaned up here
  SequenceEventListCollection newSequence;

  // For every channel, get the note events for that channel
  for (std::string& channelId : *anthem.project->generatorOrder()) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;

    getChannelNoteEventsForArrangement(channelId, arrangementId, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    if (newChannelEvents.events->size() > 0) {
      newSequence.channels->insert_or_assign(channelId, std::move(newChannelEvents));
    }
    else {
      SequenceEventList::cleanUpInstance(newChannelEvents);
    }
  }

  // Add the new sequence to the store
  auto& store = *anthem.sequenceStore;
  store.addOrUpdateSequence(arrangementId, newSequence);
}

void AnthemSequenceCompiler::compileArrangement(
  std::string arrangementId,
  std::vector<std::string>& channelIdsToRebuild
) {
  auto& store = *Anthem::getInstance().sequenceStore;

  for (auto& channelId : channelIdsToRebuild) {
    // This will leak memory if it's not assigned somewhere or cleaned up here
    SequenceEventList newChannelEvents;

    getChannelNoteEventsForArrangement(channelId, arrangementId, *newChannelEvents.events);
    sortEventList(*newChannelEvents.events);

    if (newChannelEvents.events->size() > 0) {
      store.addOrUpdateChannelInSequence(arrangementId, channelId, newChannelEvents);
    }
    else {
      // Just in case, we'll remove the channel from the sequence store. If the
      // channel used to have events and now doesn't, we want to remove it, and
      // if the channel doesn't exist in the pattern then this will be a no-op.
      store.removeChannelFromSequence(arrangementId, channelId);

      SequenceEventList::cleanUpInstance(newChannelEvents);
    }
  }
}

void AnthemSequenceCompiler::cleanUpChannel(std::string channelId) {
  auto& store = *Anthem::getInstance().sequenceStore;

  store.removeChannelFromAllSequences(channelId);
}

void AnthemSequenceCompiler::getChannelNoteEventsForArrangement(
  std::string channelId,
  std::string arrangementId,
  std::vector<AnthemSequenceEvent>& events
) {
  auto& anthem = Anthem::getInstance();

  auto arrangementIter = anthem.project->sequence()->arrangements()->find(arrangementId);
  if (arrangementIter == anthem.project->sequence()->arrangements()->end()) {
    return;
  }

  auto& arrangement = arrangementIter->second;

  auto& clips = arrangement->clips();

  for (auto& clipPair : *clips) {
    auto clip = clipPair.second;

    getChannelNoteEventsForPattern(
      channelId,
      clip->patternId(),
      clip->timeView().has_value()
          ? std::make_optional(
              std::make_tuple(
                static_cast<double>(clip->timeView().value()->start()),
                static_cast<double>(clip->timeView().value()->end())
              )
            )
          : std::nullopt,
      static_cast<double>(clip->offset()),
      events
    );
  }
}

void AnthemSequenceCompiler::getChannelNoteEventsForPattern(
  std::string channelId,
  std::string patternId,
  std::optional<std::tuple<double, double>> range,
  std::optional<double> offset,
  std::vector<AnthemSequenceEvent>& events
) {
  auto& anthem = Anthem::getInstance();

  auto patternIter = anthem.project->sequence()->patterns()->find(patternId);
  if (patternIter == anthem.project->sequence()->patterns()->end()) {
    return;
  }

  auto pattern = patternIter->second;

  auto notesIter = pattern->notes()->find(channelId);
  if (notesIter == pattern->notes()->end()) {
    return;
  }

  auto notes = notesIter->second;

  for (auto& note : *notes) {
    auto rangeOptional = clampStartAndEndToRange(
      static_cast<double>(note->offset()),
      static_cast<double>(note->offset()),
      range
    );

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

    events.push_back(AnthemSequenceEvent {
      .offset = startWithOffset,
      .event = AnthemEvent {
        .type = AnthemEventType::NoteOn,
        .noteOn = AnthemNoteOnEvent(
          static_cast<int16_t>(note->key()),
          static_cast<int16_t>(0),
          static_cast<float>(note->velocity()),
          0.f,
          static_cast<int32_t>(-1)
        )
      }
    });

    events.push_back(AnthemSequenceEvent {
      .offset = endWithOffset,
      .event = AnthemEvent {
        .type = AnthemEventType::NoteOff,
        .noteOff = AnthemNoteOffEvent(
          static_cast<int16_t>(note->key()),
          static_cast<int16_t>(0),
          0.f,
          static_cast<int32_t>(-1)
        )
      }
    });
  }
}

void AnthemSequenceCompiler::sortEventList(std::vector<AnthemSequenceEvent>& events) {
  std::sort(events.begin(), events.end(), [](const AnthemSequenceEvent& a, const AnthemSequenceEvent& b) {
    return a.offset < b.offset;
  });
}

std::optional<std::tuple<double, double>> AnthemSequenceCompiler::clampStartAndEndToRange(
  double start,
  double end,
  std::optional<std::tuple<double, double>> range
) {
  if (!range.has_value()) {
    return std::make_tuple(start, end);
  }

  auto [rangeStart, rangeEnd] = range.value();

  if (start < rangeStart && end < rangeStart) {
    return std::nullopt;
  }

  if (start > rangeEnd && end > rangeEnd) {
    return std::nullopt;
  }

  return std::make_tuple(
    clampTimeToRange(start, range.value()),
    clampTimeToRange(end, range.value())
  );
}

double AnthemSequenceCompiler::clampTimeToRange(
  double time,
  std::tuple<double, double> range
) {
  auto [start, end] = range;

  if (time < start) {
    return start;
  }

  if (time > end) {
    return end;
  }

  return time;
}
