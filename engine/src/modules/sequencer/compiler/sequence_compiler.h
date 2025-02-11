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

#pragma once

#include "modules/sequencer/events/event.h"

#include <string>
#include <vector>
#include <optional>

// This class is used to compile a sequence into a set of sorted event lists.
//
// In Anthem, the sequence model is complex. To manage the complexity with
// respect to the audio thread, we "compile" sequences into time-sorted lists of
// events for each channel. These lists are much easier to deal with from the
// sequencer's perspective. The runtime component of the sequencer doesn't even
// know about patterns - it just sees these event lists.
//
// We store event lists for each arrangement and for each pattern. When
// something is changed, e.g. some notes are moved around for a given pattern,
// we don't recompile the entire sequence. Instead, we just update the event
// lists for the relevant channel.
class AnthemSequenceCompiler {
friend class SequenceCompilerTest;
private:
  static void getChannelEventsForArrangement(std::string channelId, std::string arrangementId, std::vector<AnthemSequenceEvent>& events);

  static void getChannelEventsForPattern(
    std::string channelId,
    std::string patternId,
    std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> range,
    std::optional<AnthemSequenceTime> offset,
    std::vector<AnthemSequenceEvent>& events
  );

  // Gets the note events on a given channel for the given pattern.
  //
  // If a range is provided, the events will be clamped to that range.
  //
  // If an offset is provided, the events will be offset by that amount. This is
  // used, for example, when creating the event list for a pattern clip in an
  // arrangement. The clip has its own offset, so we need to offset the events
  // in that case. If we are just generating event lists for a pattern, the
  // offset will be nullopt.
  //
  // The events will not be sorted. In the case of compiling an arrangement, a
  // given channel may have notes from many clips, so we call this method
  // multiple times and sort at the end.
  static void getChannelNoteEventsForPattern(
    std::string channelId,
    std::string patternId,
    std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> range,
    std::optional<AnthemSequenceTime> offset,
    std::vector<AnthemSequenceEvent>& events
  );

  static void sortEventList(std::vector<AnthemSequenceEvent>& events);

  // Clamps a time range to the start and end times of a clip. The intent here
  // is for events with durations (e.g. note, audio) to be clamped to the start
  // and end times of a pattern clip.
  //
  // If std::nullopt is passed for range, this is effectively a no-op.
  //
  // If std::nullopt is returned, it means the event was entirely outside the
  // range.
  static std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> clampStartAndEndToRange(
    AnthemSequenceTime start,
    AnthemSequenceTime end,
    std::optional<std::tuple<AnthemSequenceTime, AnthemSequenceTime>> range
  );

  // Clamps a given timestamp to the given range.
  static AnthemSequenceTime clampTimeToRange(
    AnthemSequenceTime time,
    std::tuple<AnthemSequenceTime, AnthemSequenceTime> range
  );
public:
};
