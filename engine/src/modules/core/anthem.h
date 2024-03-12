/*
  Copyright (C) 2023 - 2024 Joshua Wade

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
#include <iostream>

#include <juce_audio_devices/juce_audio_devices.h>

#include "anthem_audio_callback.h"
#include "anthem_graph.h"
#include "master_output_node.h"

#include "id_generator.h"

class Anthem {
private:
  juce::AudioDeviceManager deviceManager;
  std::unique_ptr<AnthemAudioCallback> audioCallback;

  std::shared_ptr<AnthemGraph> processingGraph;

  std::shared_ptr<AnthemGraphNode> masterOutputNode;
  uint64_t masterOutputNodeId;

  std::map<uint64_t, std::shared_ptr<AnthemGraphNode>> nodes;

  // Initializes the engine
  void init();
public:
  Anthem();

  std::shared_ptr<AnthemGraph> getProcessingGraph() {
    return processingGraph;
  }

  std::shared_ptr<AnthemGraphNode> getMasterOutputNode() {
    return masterOutputNode;
  }

  std::shared_ptr<AnthemGraphNode> getNode(uint64_t nodeId) {
    return nodes[nodeId];
  }

  bool hasNode(uint64_t nodeId) {
    return nodes.find(nodeId) != nodes.end();
  }

  uint64_t getMasterOutputNodeId() {
    return masterOutputNodeId;
  }

  uint64_t addNode(std::shared_ptr<AnthemProcessor> processor) {
    auto id = GlobalIDGenerator::generateID();
    auto node = this->processingGraph->addNode(processor);
    nodes[id] = node;
    return id;
  }

  bool removeNode(uint64_t nodeId) {
    if (!hasNode(nodeId)) {
      return false;
    }

    auto node = getNode(nodeId);
    this->processingGraph->removeNode(node);
    nodes.erase(nodeId);
    return true;
  }
};
