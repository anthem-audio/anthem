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

#include "generated/lib/model/processing_graph/node_port_config.h"
#include "modules/processing_graph/model/node_connection.h"

#include <juce_core/juce_core.h>
#include <memory>

class AnthemGraphNodeConnection;
class AnthemNodeProcessContext;

class AnthemGraphCompilerEdge {
private:
  JUCE_LEAK_DETECTOR(AnthemGraphCompilerEdge)
public:
  // The edge in the node graph
  std::shared_ptr<NodeConnection> edgeSource;

  AnthemNodeProcessContext* sourceNodeContext;

  AnthemNodeProcessContext* destinationNodeContext;

  // The type of this edge
  NodePortDataType type;

  // Whether this edge has been processed
  bool processed = false;

  AnthemGraphCompilerEdge(std::shared_ptr<NodeConnection> edge,
      AnthemNodeProcessContext* sourceNodeContext,
      AnthemNodeProcessContext* destinationNodeContext,
      NodePortDataType type)
    : edgeSource(edge), sourceNodeContext(sourceNodeContext),
      destinationNodeContext(destinationNodeContext), type(type) {}
};
