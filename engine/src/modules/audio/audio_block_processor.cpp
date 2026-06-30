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

#include "audio_block_processor.h"

#include "modules/core/visualization/global_visualization_sources.h"
#include "modules/processing_graph/graph_processor.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"
#include "modules/sequencer/runtime/transport.h"

#include <chrono>

namespace anthem {

AudioBlockProcessor::AudioBlockProcessor(Transport& transport,
    RuntimeSequenceStore& sequenceStore,
    RuntimeAutomationSequenceStore& automationSequenceStore,
    GraphProcessor& graphProcessor,
    GlobalVisualizationSources& globalVisualizationSources)
  : transport(transport), sequenceStore(sequenceStore),
    automationSequenceStore(automationSequenceStore), graphProcessor(graphProcessor),
    globalVisualizationSources(globalVisualizationSources) {}

bool AudioBlockProcessor::processAudioBlock(
    int numSamples, double sampleRate, uint64_t audioProcessingConfigGeneration) {
  auto startTime = std::chrono::high_resolution_clock::now();

  transport.rt_prepareForProcessingBlock();
  const auto blockStartSample = transport.rt_sampleCounter;

  sequenceStore.rt_processSequenceChanges(numSamples);
  automationSequenceStore.rt_processSequenceChanges(numSamples);

  const auto didProcessGraph =
      graphProcessor.rt_process(numSamples, audioProcessingConfigGeneration);

  auto endTime = std::chrono::high_resolution_clock::now();

  auto duration =
      std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
  auto durationInSeconds = static_cast<double>(duration) / 1e6;
  jassert(sampleRate >= 0.0);
  auto cpuBurden = durationInSeconds * sampleRate /
                   static_cast<double>(numSamples); // actual time / total buffer time

  auto cpuBurdenProvider = globalVisualizationSources.cpuBurdenProvider.rt_getProvider();
  auto playheadPositionProvider =
      globalVisualizationSources.playheadPositionProvider.rt_getProvider();
  auto playheadSequenceIdProvider =
      globalVisualizationSources.playheadSequenceIdProvider.rt_getProvider();

  cpuBurdenProvider->rt_updateCpuBurden(cpuBurden, blockStartSample, numSamples, sampleRate);

  playheadPositionProvider->rt_updatePlayheadPosition(
      transport, blockStartSample, numSamples, sampleRate);

  auto& activeSequenceId = transport.rt_config->activeSequenceId;
  if (activeSequenceId.has_value()) {
    playheadSequenceIdProvider->rt_updatePlayheadSequenceId(*activeSequenceId, blockStartSample);
  }

  transport.rt_advancePlayhead(numSamples);
  sequenceStore.rt_cleanupAfterBlock();

  return didProcessGraph;
}

} // namespace anthem
