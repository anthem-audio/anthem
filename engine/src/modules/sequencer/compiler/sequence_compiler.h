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

#include <cstdint>
#include <optional>
#include <vector>

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
namespace anthem {

class SequenceCompiler {
  friend class SequenceCompilerTest;
public:
  using EntityId = int64_t;

  // Compiles the given pattern, and adds or replaces its entry in the sequence
  // store.
  static void compilePattern(EntityId patternId);

  // Compiles the given tracks for the given pattern, and replaces them in the
  // sequence store.
  static void compilePattern(EntityId patternId,
      std::vector<EntityId>& trackIdsToRebuild,
      std::vector<std::tuple<double, double>>& invalidationRanges);

  // Compiles the given arrangement, and adds or replaces its entry in the
  // sequence store.
  static void compileArrangement(EntityId arrangementId);

  // Compiles the given tracks for the given arrangement, and replaces them in
  // the sequence store.
  static void compileArrangement(EntityId arrangementId,
      std::vector<EntityId>& trackIdsToRebuild,
      std::vector<std::tuple<double, double>>& invalidationRanges);

  // Cleans up any sequences related to the given track ID.
  static void cleanUpTrack(EntityId trackId);
private:
  // Gets the note events on a given track for the given arrangement.
  //
  // The events will be added to the given `events` vector.
  static void getTrackNoteEventsForArrangement(
      EntityId trackId, EntityId arrangementId, std::vector<SequenceEvent>& events);

  // Gets the note events for the given pattern.
  //
  // The events will be added to the given `events` vector.
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
  // given track may have notes from many clips, so we call this method
  // multiple times and sort at the end.
  static void getPatternNoteEvents(EntityId patternId,
      std::optional<EntityId> clipId,
      std::optional<std::tuple<double, double>> range,
      std::optional<double> offset,
      std::vector<SequenceEvent>& events);

  static void sortEventList(std::vector<SequenceEvent>& events);

  // Clamps a time range to the start and end times of a clip. The intent here
  // is for events with durations (e.g. note, audio) to be clamped to the start
  // and end times of a pattern clip.
  //
  // If std::nullopt is passed for range, this is effectively a no-op.
  //
  // If std::nullopt is returned, it means the event was entirely outside the
  // range.
  static std::optional<std::tuple<double, double>> clampStartAndEndToRange(
      double start, double end, std::optional<std::tuple<double, double>> range);

  // Clamps a given timestamp to the given range.
  static double clampTimeToRange(double time, const std::tuple<double, double>& range);
};

} // namespace anthem
