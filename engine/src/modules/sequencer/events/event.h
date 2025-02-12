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

enum AnthemEventType {
  NoteOn,
  NoteOff
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
  };
};

// A time for a sequence event.
struct AnthemSequenceTime {
  // The number of ticks since the start of the sequence.
  //
  // This should be a uint64_t; however, Dart only supports signed integers, and
  // since this data comes directly from the Dart model, we can't take advantage
  // of the full range of uint64_t.
  int64_t ticks;

  // A normalized fraction of a tick, in the range [0, 1).
  double fraction;

  bool operator<(const AnthemSequenceTime& other) const {
    return ticks < other.ticks || (ticks == other.ticks && fraction < other.fraction);
  }

  bool operator==(const AnthemSequenceTime& other) const {
    return ticks == other.ticks && fraction == other.fraction;
  }

  bool operator>(const AnthemSequenceTime& other) const {
    return ticks > other.ticks || (ticks == other.ticks && fraction > other.fraction);
  }

  bool operator<=(const AnthemSequenceTime& other) const {
    return *this < other || *this == other;
  }

  bool operator>=(const AnthemSequenceTime& other) const {
    return *this > other || *this == other;
  }

  bool operator!=(const AnthemSequenceTime& other) const {
    return !(*this == other);
  }

  AnthemSequenceTime operator+(const AnthemSequenceTime& other) const {
    // Calculate the sum of the fractional components.
    double newFraction = fraction + other.fraction;

    // Calculate the carry from the fractional component.
    int64_t carry = newFraction >= 1.0 ? 1 : 0;

    // Calculate the sum of the tick components.
    int64_t newTicks = ticks + other.ticks + carry;

    // If we carried, subtract 1 from the fractional component.
    newFraction -= carry;

    return AnthemSequenceTime { .ticks = newTicks, .fraction = newFraction };
  }

  AnthemSequenceTime operator-(const AnthemSequenceTime& other) const {
    // Calculate the difference of the fractional components.
    double newFraction = fraction - other.fraction;

    // Calculate the borrow from the fractional component.
    int64_t borrow = newFraction < 0.0 ? 1 : 0;

    // Calculate the difference of the tick components.
    int64_t newTicks = ticks - other.ticks - borrow;

    newFraction += borrow;

    return AnthemSequenceTime { .ticks = newTicks, .fraction = newFraction };
  }
};

struct AnthemSequenceEvent {
  // The time of the event, relative to the start of the sequence.
  AnthemSequenceTime time;

  // The event itself.
  AnthemEvent event;

  bool operator<(const AnthemSequenceEvent& other) const {
    return time < other.time;
  }

  bool operator==(const AnthemSequenceEvent& other) const {
    return time == other.time;
  }

  bool operator>(const AnthemSequenceEvent& other) const {
    return time > other.time;
  }

  bool operator<=(const AnthemSequenceEvent& other) const {
    return time <= other.time;
  }

  bool operator>=(const AnthemSequenceEvent& other) const {
    return time >= other.time;
  }

  bool operator!=(const AnthemSequenceEvent& other) const {
    return time != other.time;
  }
};

// A time for a processing graph event.
struct AnthemLiveTime {
  // The number of samples since the start of the processing block.
  int64_t offset;
};

struct AnthemLiveEvent {
  // The time of the event, relative to the start of the processing block.
  AnthemLiveTime time;

  // The event itself.
  AnthemEvent event;
};
