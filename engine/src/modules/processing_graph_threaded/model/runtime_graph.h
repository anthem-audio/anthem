/*
  Copyright (C) 2026 Joshua Wade

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

#include "modules/processing_graph_threaded/model/node.h"

#include <unordered_map>
#include <vector>

namespace anthem {

class ProcessingGraphModel;

} // namespace anthem

namespace anthem::threaded_graph {

class RuntimeGraph {
public:
  RuntimeGraph() = default;
  ~RuntimeGraph() = default;

  RuntimeGraph(const RuntimeGraph&) = delete;
  RuntimeGraph& operator=(const RuntimeGraph&) = delete;

  RuntimeGraph(RuntimeGraph&&) noexcept = default;
  RuntimeGraph& operator=(RuntimeGraph&&) noexcept = default;

  static RuntimeGraph fromProcessingGraph(ProcessingGraphModel& processingGraph);

  std::unordered_map<Node::Id, Node> nodes;
  std::vector<Node*> inputNodes;
};

} // namespace anthem::threaded_graph
