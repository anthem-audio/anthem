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

#include <algorithm>

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
                AnthemSequenceTime { .ticks = clip->timeView().value()->start(), .fraction = 0. },
                AnthemSequenceTime { .ticks = clip->timeView().value()->end(), .fraction = 0. }
              )
            )
          : std::nullopt,
      AnthemSequenceTime { .ticks = clip->offset(), .fraction = 0. },
      events
    );
  }
}

void AnthemSequenceCompiler::getChannelNoteEventsForPattern(
  std::string channelId,
  std::string patternId,
  std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> range,
  std::optional<AnthemSequenceTime> offset,
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
      AnthemSequenceTime { .ticks = note->offset(), .fraction = 0. },
      AnthemSequenceTime { .ticks = note->offset() + note->length(), .fraction = 0. },
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
      .time = startWithOffset,
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
      .time = endWithOffset,
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
    bool isFractionEarlier = a.time.fraction < b.time.fraction;
    bool isTickEqual = a.time.ticks == b.time.ticks;
    bool isTickEarlier = a.time.ticks < b.time.ticks;

    return (isTickEqual && isFractionEarlier) || isTickEarlier;
  });
}

std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> AnthemSequenceCompiler::clampStartAndEndToRange(
  AnthemSequenceTime start,
  AnthemSequenceTime end,
  std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> range
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

AnthemSequenceTime AnthemSequenceCompiler::clampTimeToRange(
  AnthemSequenceTime time,
  std::tuple<AnthemSequenceTime, AnthemSequenceTime> range
) {
  auto [start, end] = range;

  if (time.ticks < start.ticks || (time.ticks == start.ticks && time.fraction < start.fraction)) {
    return start;
  }

  if (time.ticks > end.ticks || (time.ticks == end.ticks && time.fraction > end.fraction)) {
    return end;
  }

  return time;
}
