/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

#include "modules/core/engine.h"

#include "modules/core/adapters/transport_adapters.h"
#include "modules/core/processing_graph_node_initialization_session.h"
#include "modules/processing_graph/model/runtime_graph.h"

#include <memory>
#include <utility>

namespace anthem {

std::unique_ptr<Engine> Engine::instance = nullptr;

Engine::Engine() = default;

void Engine::initialize() {
  this->sequenceStore = std::make_unique<RuntimeSequenceStore>();
  this->automationSequenceStore = std::make_unique<RuntimeAutomationSequenceStore>();
  transport =
      std::make_unique<Transport>(createTransportProjectView(*this), createTransportClock(*this));
  this->engineRuntimeServices =
      std::make_unique<EngineRuntimeServices>(*transport, *sequenceStore, *automationSequenceStore);
  this->graphProcessor = std::make_unique<GraphProcessor>(*engineRuntimeServices);
  globalVisualizationSources = std::make_unique<GlobalVisualizationSources>();
  audioBlockProcessor = std::make_unique<AudioBlockProcessor>(*transport,
      *sequenceStore,
      *automationSequenceStore,
      *graphProcessor,
      *globalVisualizationSources);
  audioSessionController = std::make_unique<AudioSessionController>(
      project, *graphProcessor, *transport, comms, *audioBlockProcessor, [this]() {
        resetInitializedProcessingGraphNodes();
      });
  renderController = std::make_unique<RenderController>(
      *audioSessionController, *audioBlockProcessor, *transport, comms);

#ifndef __EMSCRIPTEN__
  juce::addDefaultFormatsToManager(audioPluginFormatManager);
  juce::Logger::writeToLog(
      "Initialized audio plugin format manager with UI-capable plugin formats.");
#endif // #ifndef __EMSCRIPTEN__

  comms.init();
}

void Engine::shutdown() {
  if (renderController != nullptr) {
    renderController->stopRenderThread();
  }

  if (audioSessionController != nullptr) {
    audioSessionController->stopAudio();
  }
}

void Engine::resetInitializedProcessingGraphNodes() {
  for (auto& [_, initializedNodeWeakPtr] : initializedProcessingGraphNodes) {
    auto initializedNode = initializedNodeWeakPtr.lock();
    if (initializedNode == nullptr) {
      continue;
    }

    auto processor = initializedNode->getProcessor();
    if (processor.has_value()) {
      processor.value()->isPrepared = false;
    }
  }

  initializedProcessingGraphNodes.clear();
}

void Engine::initializeProcessingGraphNodes(InitializeProcessingGraphNodesCallback complete) {
  auto session =
      std::make_shared<ProcessingGraphNodeInitializationSession>(*this, std::move(complete));
  session->run();
}

void Engine::publishProcessingGraph() {
  auto audioProcessingConfigSnapshot =
      audioSessionController->getCurrentAudioProcessingConfigSnapshot();
  jassert(audioProcessingConfigSnapshot.has_value());
  if (!audioProcessingConfigSnapshot.has_value()) {
    return;
  }

  const auto& audioProcessingConfig = audioProcessingConfigSnapshot->config;

  auto& processingGraph = *project->processingGraph();

  auto runtimeGraph = RuntimeGraph::fromProcessingGraph(processingGraph,
      graphProcessor->getEngineRuntimeServices(),
      GraphBufferLayout{
          .numAudioChannels = audioProcessingConfig.outputChannelCount,
          .blockSize = audioProcessingConfig.blockSize,
      });

  graphProcessor->publishRuntimeGraph(
      runtimeGraph.release(), audioProcessingConfigSnapshot->generation);
}

} // namespace anthem
