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

#include <cstdint>

// Event type for note on events.
namespace anthem {

struct NoteOnEvent {
  // The pitch of the note, in the range [0, 127] <-> [C(-2), G8].
  int16_t pitch;

  // The channel of the note. 0 is the first channel.
  int16_t channel;

  // The velocity of the note on event, in the range [0, 1].
  float velocity;

  // The detune of the note on event. This is in cents.
  float detune;

  NoteOnEvent(int16_t pitch, int16_t channel, float velocity, float detune)
    : pitch(pitch), channel(channel), velocity(velocity), detune(detune) {}

  NoteOnEvent() : pitch(0), channel(0), velocity(0.0f), detune(0.0f) {}
};

// Event type for note off events.
struct NoteOffEvent {
  // The pitch of the note, in the range [0, 127] <-> [C-2, G8].
  int16_t pitch;

  // The channel of the note. 0 is the first channel.
  int16_t channel;

  // The velocity of the note off event, in the range [0, 1].
  float velocity;

  NoteOffEvent(int16_t pitch, int16_t channel, float velocity)
    : pitch(pitch), channel(channel), velocity(velocity) {}

  NoteOffEvent() : pitch(0), channel(0), velocity(0.0f) {}
};

struct AllVoicesOffEvent {
  AllVoicesOffEvent() {}
};

} // namespace anthem
