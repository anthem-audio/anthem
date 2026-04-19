/*
  Copyright (C) 2024 - 2026 Joshua Wade

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
#include "note_instance_id.h"

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
// contain durations. Time positioning is added in two different wrapper
// contexts:
// - AnthemSequenceEvent: absolute sequence position, expressed in ticks.
// - AnthemLiveEvent: block-relative position, expressed as a sample offset from
//   the start of the current processing block.
//
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
  AnthemEvent(AnthemAllVoicesOffEvent allVoicesOff)
    : type(AllVoicesOff), allVoicesOff(allVoicesOff) {}
};

struct AnthemSequenceEvent {
  // The time of the event, relative to the start of the sequence.
  double offset;

  // The deterministic source note ID for this event.
  AnthemSourceNoteId sourceId = anthemInvalidSourceNoteId;

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
  // Offset, in samples, from the start of the current processing block.
  //
  // `0.0` means "at block start". Positive values schedule the event later in
  // the block. This is the time domain used by processing-graph consumers, so
  // this must never contain sequencer ticks or seconds. The value may be
  // fractional and may be negative in edge cases where an event needs to
  // describe something that logically occurred just before the block started.
  double sampleOffset;

  // The runtime live note ID for this event.
  //
  // This should come from the generator in live_note_id_generator.h.
  //
  // This is assigned by note-producing processors and is the identity that
  // downstream processors should use to track active notes. Non-note events
  // should leave this as `anthemInvalidLiveNoteId`.
  AnthemLiveNoteId liveId = anthemInvalidLiveNoteId;

  // The event itself.
  AnthemEvent event;
};
