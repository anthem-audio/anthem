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

#include "modules/core/anthem_audio_callback.h"
#include "modules/processing_graph/anthem_graph.h"
#include "modules/processors/master_output.h"

#include "modules/util/id_generator.h"

#include "project.h"

class Anthem {
private:
  bool isAudioCallbackRunning;

  // Singleton shared pointer instance
  static std::shared_ptr<Anthem> instance;

  juce::AudioDeviceManager deviceManager;
  std::unique_ptr<AnthemAudioCallback> audioCallback;

  std::shared_ptr<AnthemGraph> processingGraph;

  std::shared_ptr<AnthemGraphNode> masterOutputNode;
  uint64_t masterOutputNodeId;

  std::map<uint64_t, std::shared_ptr<AnthemGraphNode>> nodes;

  // Sets up the audio callback
  void startAudioCallback();
public:
    std::shared_ptr<Project> project;

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

  uint64_t addNode(std::unique_ptr<AnthemProcessor> processor) {
    auto id = GlobalIDGenerator::generateID();
    auto node = this->processingGraph->addNode(std::move(processor));
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

  // Singleton instance getter
  static std::shared_ptr<Anthem> getInstancePtr() {
    if (!instance) {
      instance = std::make_shared<Anthem>();
    }
    return instance;
  }

  // Singleton instance getter
  static Anthem& getInstance() {
    if (!instance) {
      instance = std::make_shared<Anthem>();
    }
    return *instance;
  }

  // TODO: These generic config items should be settable, which means they
  // should live in the actual synced model.
  static const int SAMPLE_RATE = 44100;
  static const int NUM_CHANNELS = 2;
};
