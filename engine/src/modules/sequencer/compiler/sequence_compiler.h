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
  static void getChannelEventsForPattern(std::string channelId, std::string patternId, std::vector<AnthemSequenceEvent>& events);
  static void sortEventList(std::vector<AnthemSequenceEvent>& events);
public:
};
