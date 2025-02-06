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

void AnthemSequenceCompiler::getChannelEventsForArrangement(std::string channelId, std::string arrangementId, std::vector<AnthemSequenceEvent>& events) {}

void AnthemSequenceCompiler::getChannelEventsForPattern(std::string channelId, std::string patternId, std::vector<AnthemSequenceEvent>& events) {}

void AnthemSequenceCompiler::sortEventList(std::vector<AnthemSequenceEvent>& events) {
  std::sort(events.begin(), events.end(), [](const AnthemSequenceEvent& a, const AnthemSequenceEvent& b) {
    bool isFractionEarlier = a.time.fraction < b.time.fraction;
    bool isTickEqual = a.time.ticks == b.time.ticks;
    bool isTickEarlier = a.time.ticks < b.time.ticks;

    return (isTickEqual && isFractionEarlier) || isTickEarlier;
  });
}
