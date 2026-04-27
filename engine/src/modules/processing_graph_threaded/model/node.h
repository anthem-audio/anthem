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

#include <cstddef>
#include <cstdint>
#include <vector>

namespace anthem::threaded_graph {

struct Node {
  using Id = int64_t;

  // This matches the ID from the project model's processing graph node.
  Id id;

  // Number of unique nodes that must finish before this node can process.
  size_t upstreamNodeCount = 0;

  // Non-owning pointers to nodes owned by the RuntimeGraph.
  std::vector<Node*> outgoingConnections;
};

} // namespace anthem::threaded_graph
