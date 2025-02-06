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

#include "modules/sequencer/compiler/sequence_compiler.h"

class SequenceCompilerTest : public juce::UnitTest {
  bool isSorted(const std::vector<AnthemSequenceEvent>& events) {
    for (int i = 0; i < events.size(); i++) {
      if (i > 0) {
        if (events.at(i).time.ticks < events.at(i - 1).time.ticks ||
            (events.at(i).time.ticks == events.at(i - 1).time.ticks &&
            events.at(i).time.fraction < events.at(i - 1).time.fraction)) {
          return false;
        }
      }
    }

    return true;
  }

public:
  SequenceCompilerTest() : juce::UnitTest("SequenceCompilerTest", "Anthem") {}

  void runTest() override {
    {
      beginTest("Event sorting");
      auto eventList = std::vector<AnthemSequenceEvent>();
      AnthemSequenceCompiler::sortEventList(eventList);

      eventList.push_back(AnthemSequenceEvent {
        .time = AnthemSequenceTime {
          .ticks = 0,
          .fraction = 0.
        },
        .event = AnthemEvent {
          .type = AnthemEventType::NoteOn,
          .noteOn = AnthemNoteOnEvent()
        }
      });

      eventList.push_back(AnthemSequenceEvent {
        .time = AnthemSequenceTime {
          .ticks = 1,
          .fraction = 0.5
        },
        .event = AnthemEvent {
          .type = AnthemEventType::NoteOn,
          .noteOn = AnthemNoteOnEvent()
        }
      });

      eventList.push_back(AnthemSequenceEvent {
        .time = AnthemSequenceTime {
          .ticks = 1,
          .fraction = 0.
        },
        .event = AnthemEvent {
          .type = AnthemEventType::NoteOn,
          .noteOn = AnthemNoteOnEvent()
        }
      });

      AnthemSequenceCompiler::sortEventList(eventList);

      expect(eventList.size() == 3, "There are three events");
      for (int i = 0; i < eventList.size(); i++) {
        if (i > 0) {
          expect(isSorted(eventList), "The events are sorted");
        }
      }
    }
  }
};

static SequenceCompilerTest sequenceCompilerTest;
