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

/*
  Steps to compile a processing graph:

  1. Clear buffers for all nodes. For parameters, write the control values to
     the control input port buffers as an initialization value. This may be
     overwritten by actual control connections.
  2. Find all nodes that have no incoming connections. These are the "root"
     nodes of the graph. Mark these as ready to process.
  3. For each ready node, add it to a processing step it and mark all of its
     outgoing connections as ready to process.
  4. For each ready connection, add it to a processing step to copy the data
     from the source port to the destination port. This must be done in a single
     thread in series, because if multiple connections are copying to the same
     port, two threads cannot be copying the data at the same time.
  5. Find all nodes whose incoming connections are all marked as processed. Mark
     these as ready to process.
  6. Repeat steps 3-5 until all nodes are marked as processed.
*/

#pragma once

#include <memory>

#include "modules/core/constants.h"
#include "modules/processing_graph/events/anthem_processor_event.h"
#include "modules/processing_graph/topology/anthem_graph_topology.h"
#include "modules/util/arena_allocator.h"

#include "anthem_graph_compilation_result.h"
#include "anthem_graph_compiler_node.h"

#include "actions/clear_buffers_action.h"
#include "actions/process_node_action.h"
#include "actions/copy_audio_buffer_action.h"
#include "actions/copy_control_buffer_action.h"
#include "actions/write_parameters_to_control_inputs_action.h"
#include "actions/copy_note_events_action.h"

// This class is used to compile a processing graph into a set of processing
// instructions that can be executed in a real-time context.
class AnthemGraphCompiler {
public:
  static AnthemGraphCompilationResult* compile(AnthemGraphTopology& topology);
};
