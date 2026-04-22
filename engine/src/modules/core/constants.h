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

// The default size for an event buffer, in number of events.
//
// This is the size of each event buffer when it is first allocated. If the
// buffer is filled during processing, it may grow up to
// MAX_EVENT_BUFFER_SIZE. Event buffers own their own storage, so each port can
// adapt independently without requiring graph-wide memory budgeting.
//
// For context, event buffers are used whenever a node in the processing graph
// needs to send events to another node, or when a node needs to receive events
// from either the sequencer or another node.
namespace anthem {

const int DEFAULT_EVENT_BUFFER_SIZE = 1024;

// The maximum size for an event buffer, in number of events.
//
// This acts as a hard safety cap for pathological graphs or runaway event
// generation. Once a buffer reaches this size, new events for that buffer are
// dropped for the remainder of the current block.
const int MAX_EVENT_BUFFER_SIZE = 32768;

} // namespace anthem
