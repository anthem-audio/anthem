/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include "note_events.h"

// The event type. This determines ordering for events that occur at the same
// time - e.g. NoteOff must come before NoteOn.
enum AnthemEventType {
  AllVoicesOff,
  NoteOff,
  NoteOn,
};

// An event that can occur in Anthem.
//
// This should always be absent of absolute time information, though it may
// contain durations. The time information is provided in two different
// contexts:
// - AnthemSequenceEvent: In the context of a sequence, the time is the absolute
//   time of the event in ticks, along with a fractional component.
// - AnthemLiveEvent: In the context of the processing graph, the time is the
//   time in samples since the start of the processing block; note that this
//   value can be negative.
struct AnthemEvent {
  AnthemEventType type;
  
  union {
    AnthemNoteOnEvent noteOn;
    AnthemNoteOffEvent noteOff;
    AnthemAllVoicesOffEvent allVoicesOff;
  };

  AnthemEvent() : type(AllVoicesOff), allVoicesOff{} {}
  AnthemEvent(AnthemNoteOnEvent noteOn) : type(NoteOn), noteOn(noteOn) {}
  AnthemEvent(AnthemNoteOffEvent noteOff) : type(NoteOff), noteOff(noteOff) {}
  AnthemEvent(AnthemAllVoicesOffEvent allVoicesOff) : type(AllVoicesOff), allVoicesOff(allVoicesOff) {}
};

struct AnthemSequenceEvent {
  // The time of the event, relative to the start of the sequence.
  double offset;

  // The event itself.
  AnthemEvent event;

  bool operator<(const AnthemSequenceEvent& other) const {
    return offset < other.offset;
  }

  bool operator>(const AnthemSequenceEvent& other) const {
    return offset > other.offset;
  }

  bool operator<=(const AnthemSequenceEvent& other) const {
    return offset <= other.offset;
  }

  bool operator>=(const AnthemSequenceEvent& other) const {
    return offset >= other.offset;
  }
};

struct AnthemLiveEvent {
  // The time of the event, relative to the start of the processing block.
  double time;

  // The event itself.
  AnthemEvent event;
};
