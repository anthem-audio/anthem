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

#include <vector>
#include <memory>

#include "anthem_graph_node.h"

// This is a container for the processing graph. It holds nodes and their
// connections, and it can be cloned to create a new graph with the same
// structure.
//
// There are always two instances of this class: one for the main thread,
// and one for the audio thread. The audio thread instance is treated as
// read-only. When the main thread instance is modified, it is cloned and
// sent to the audio thread, and the audio thread replaces its instance
// with the new one as soon as it finishes its current processing cycle.
class AnthemGraphTopology {
private:
  std::vector<std::shared_ptr<AnthemGraphNode>> nodes;
public:
  AnthemGraphTopology();

  void addNode(std::shared_ptr<AnthemGraphNode> node);

  std::unique_ptr<AnthemGraphTopology> clone();
};

// TODO: This will need to be properly freed, even if there are shared pointers
// everywhere. Shared pointers don't deal with cycles, so we need to unlink
// everything before releasing the last reference.
//
// Maybe we should use weak pointers for the connections between nodes?
