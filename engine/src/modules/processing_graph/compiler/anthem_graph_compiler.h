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

#include "actions/clear_buffers_action.h"
#include "actions/copy_audio_buffer_action.h"
#include "actions/copy_control_buffer_action.h"
#include "actions/copy_events_action.h"
#include "actions/process_node_action.h"
#include "actions/write_parameters_to_control_inputs_action.h"
#include "anthem_graph_compilation_result.h"
#include "anthem_graph_compiler_node.h"
#include "anthem_graph_process_context.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_connection.h"

#include <memory>

class GraphRuntimeServices;

struct AnthemGraphCompileRequest {
  using NodeMap = AnthemModelUnorderedMap<int64_t, std::shared_ptr<Node>>;
  using ConnectionMap = AnthemModelUnorderedMap<int64_t, std::shared_ptr<NodeConnection>>;

  GraphRuntimeServices& rtServices;
  NodeMap& nodes;
  ConnectionMap& connections;
  AnthemGraphBufferLayout bufferLayout;
  double sampleRate = 0.0;
};

// This class is used to compile a processing graph into a set of processing
// instructions that can be executed in a real-time context.
class AnthemGraphCompiler {
public:
  static AnthemGraphCompilationResult* compile(const AnthemGraphCompileRequest& request);
};
