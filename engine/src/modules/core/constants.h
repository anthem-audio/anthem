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

// Max audio buffer size
const int MAX_AUDIO_BUFFER_SIZE = 480;

// The default size for an event buffer, in number of events.
//
// This is the size of each event buffer when it is first allocated. If the
// buffer is filled during processing, it will be reallocated to a larger size.
// This is done via an arena allocator. The space in the arena is allocated
// ahead of time, which allows for dynamic reallocation on the audio thread
// without real-time safety issues.
//
// For context, event buffers are used whenever a node in the processing graph
// needs to send events to another node, or when a node needs to receive events
// from either the sequencer or another node.
const int DEFAULT_EVENT_BUFFER_SIZE = 1024;
