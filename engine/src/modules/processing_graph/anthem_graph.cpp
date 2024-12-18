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

#include "anthem_graph.h"

#include <iostream>

AnthemGraph::AnthemGraph() {
  topology = std::make_unique<AnthemGraphTopology>();
  compiler = std::make_unique<AnthemGraphCompiler>();
  graphProcessor = std::make_unique<AnthemGraphProcessor>();
}

std::shared_ptr<AnthemGraphNode> AnthemGraph::addNode(std::unique_ptr<AnthemProcessor> processor) {
  auto node = AnthemGraphNode::create(std::move(processor));
  topology->addNode(node);
  return node;
}

void AnthemGraph::removeNode(std::shared_ptr<AnthemGraphNode> node) {
  topology->removeNode(node);
}

void AnthemGraph::connectNodes(
  std::shared_ptr<AnthemGraphNodePort> source,
  std::shared_ptr<AnthemGraphNodePort> destination
) {
  topology->addConnection(source, destination);
}

void AnthemGraph::disconnectNodes(
  std::shared_ptr<AnthemGraphNodePort> source,
  std::shared_ptr<AnthemGraphNodePort> destination
) {
  topology->removeConnection(source, destination);
}

void AnthemGraph::sendCompiledGraphToProcessor(AnthemGraphCompilationResult* compiledGraph) {
  graphProcessor->setProcessingStepsFromMainThread(compiledGraph);
}

void AnthemGraph::compile() {
  sendCompiledGraphToProcessor(compiler->compile());
}

void AnthemGraph::debugPrint() {
  std::cout << "AnthemGraph" << std::endl;
  std::cout << topology->getNodes().size() << " nodes" << std::endl;
  std::cout << topology->getConnections().size() << " edges" << std::endl;

  std::cout << std::endl;
}
