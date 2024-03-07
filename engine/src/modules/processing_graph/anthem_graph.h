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

#include <memory>

#include "anthem_graph_node.h"
#include "anthem_processor.h"
#include "anthem_graph_topology.h"
#include "anthem_graph_compiler.h"
#include "anthem_graph_processor.h"

// This class is used to store processors and their connections, and to manage
// the flow of audio, MIDI and control data between them.
class AnthemGraph {
private:
  std::unique_ptr<AnthemGraphTopology> topology;
  std::unique_ptr<AnthemGraphCompiler> compiler;
  std::unique_ptr<AnthemGraphProcessor> graphProcessor;

  // This method is called when the graph is updated, and it updates the
  // graph processor.
  void sendCompiledGraphToProcessor(std::shared_ptr<AnthemGraphCompilationResult> compiledGraph);
public:
  AnthemGraph();

  AnthemGraphTopology& getTopology() {
    return *topology;
  }

  // Allows a node to be added to the graph.
  std::shared_ptr<AnthemGraphNode> addNode(std::shared_ptr<AnthemProcessor> processor);

  // TODO: Add a way to remove nodes

  void connectNodes(
    std::shared_ptr<AnthemGraphNodePort> source,
    std::shared_ptr<AnthemGraphNodePort> destination
  );

  // void disconnectNodes(std::shared_ptr<AnthemAudioInput> input, std::shared_ptr<AnthemAudioOutput> output);

  AnthemGraphProcessor& getProcessor() {
    return *graphProcessor;
  }

  void compile();

  void debugPrint();
};
