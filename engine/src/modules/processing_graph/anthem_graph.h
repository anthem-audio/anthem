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
  // The topology for this graph
  std::unique_ptr<AnthemGraphTopology> topology;

  // The compiler, which turns the topology into processing steps
  std::unique_ptr<AnthemGraphCompiler> compiler;

  // The processor, which takes the compilation result from the compiler and
  // uses it on the audio thread to process data in the graph
  std::unique_ptr<AnthemGraphProcessor> graphProcessor;

  // This method is called when the graph is updated, and it updates the
  // graph processor.
  void sendCompiledGraphToProcessor(std::shared_ptr<AnthemGraphCompilationResult> compiledGraph);
public:
  AnthemGraph();

  AnthemGraphTopology& getTopology() {
    return *topology;
  }

  // Wraps a processor with a graph node, and adds the node to the graph.
  std::shared_ptr<AnthemGraphNode> addNode(std::shared_ptr<AnthemProcessor> processor);

  // Removes a node from the graph.
  void removeNode(std::shared_ptr<AnthemGraphNode> node);

  void connectNodes(
    std::shared_ptr<AnthemGraphNodePort> source,
    std::shared_ptr<AnthemGraphNodePort> destination
  );

  void disconnectNodes(
    std::shared_ptr<AnthemGraphNodePort> source,
    std::shared_ptr<AnthemGraphNodePort> destination
  );

  AnthemGraphProcessor& getProcessor() {
    return *graphProcessor;
  }

  // Compiles the topology, and pushes the result to the audio thread
  void compile();

  void debugPrint();
};
