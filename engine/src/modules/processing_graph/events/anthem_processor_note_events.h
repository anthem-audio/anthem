/*
  Copyright (C) 2024 Joshua Wade

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
struct NoteOnEvent {
  // The pitch of the note, in the range [0, 127] <-> [C-2, G8].
  int16_t pitch;

  // The channel of the note. 0 is the first channel.
  int16_t channel;

  // The velocity of the note on event, in the range [0, 1].
  float velocity;

  // The detune of the note on event. This is in cents.
  float detune;

  // Optional. The id of the note on event. This is used to match note on and
  // note off events.
  int32_t id;

  // Constructor
  NoteOnEvent(int16_t pitch, int16_t channel, float velocity, float detune, int32_t id) : pitch(pitch), channel(channel), velocity(velocity), detune(detune), id(id) {}
};

// Event type for note off events.
struct NoteOffEvent {
  // The pitch of the note, in the range [0, 127] <-> [C-2, G8].
  int16_t pitch;

  // The channel of the note. 0 is the first channel.
  int16_t channel;

  // The velocity of the note off event, in the range [0, 1].
  float velocity;

  // Optional. The id of the note off event. This is used to match note on and
  // note off events.
  int32_t id;

  // Constructor
  NoteOffEvent(int16_t pitch, int16_t channel, float velocity, int32_t id) : pitch(pitch), channel(channel), velocity(velocity), id(id) {}
};
