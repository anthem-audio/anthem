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

#include "modules/processing_graph/model/runtime_node.h"
#include "modules/processing_graph/runtime/graph_process_context.h"

#include <cstddef>
#include <memory>
#include <queue>
#include <unordered_map>
#include <vector>

namespace anthem {

class GraphRuntimeServices;
class ProcessingGraphModel;

class RuntimeNodePriorityComparator {
public:
  bool operator()(const RuntimeNode* left, const RuntimeNode* right) const;
};

class RuntimeGraph {
public:
  using AvailableTaskQueue =
      std::priority_queue<RuntimeNode*, std::vector<RuntimeNode*>, RuntimeNodePriorityComparator>;

  RuntimeGraph();
  explicit RuntimeGraph(size_t nodeCapacity);
  ~RuntimeGraph();

  RuntimeGraph(const RuntimeGraph&) = delete;
  RuntimeGraph& operator=(const RuntimeGraph&) = delete;

  RuntimeGraph(RuntimeGraph&&) = delete;
  RuntimeGraph& operator=(RuntimeGraph&&) = delete;

  static std::unique_ptr<RuntimeGraph> fromProcessingGraph(ProcessingGraphModel& processingGraph,
      GraphRuntimeServices& rtServices,
      const GraphBufferLayout& bufferLayout);

  void cleanup();

  std::unordered_map<RuntimeNode::Id, RuntimeNode> nodes;
  std::vector<RuntimeNode*> inputNodes;
  AvailableTaskQueue availableTasks;
  std::unique_ptr<GraphProcessContext> graphProcessContext;
private:
  bool hasCleanedUp = false;

  static AvailableTaskQueue createAvailableTaskQueue(size_t nodeCapacity);
};

} // namespace anthem
