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

#include <juce_core/juce_core.h>

namespace anthem {

AudioBlockProcessor::AudioBlockProcessor(Transport& transport,
    RuntimeSequenceStore& sequenceStore,
    RuntimeAutomationSequenceStore& automationSequenceStore,
    GraphProcessor& graphProcessor,
    GlobalVisualizationSources& globalVisualizationSources)
  : transport(transport), sequenceStore(sequenceStore),
    automationSequenceStore(automationSequenceStore), graphProcessor(graphProcessor),
    globalVisualizationSources(globalVisualizationSources) {}

AudioBlockProcessResult AudioBlockProcessor::processAudioBlock(
    int numSamples, double sampleRate, uint64_t audioProcessingConfigGeneration) {
  // Unlike std::chrono's monotonic clock, JUCE's platform clock also works in
  // AudioWorklets, where performance.now() is unavailable.
  const auto startTime = juce::Time::getHighResolutionTicks();

  numSamples = transport.rt_beginProcessingBlock(numSamples);
  const auto blockStartSample = transport.rt_sampleCounter;

  if (numSamples <= 0) {
    const auto transportResult = transport.rt_endProcessingBlock();
    return AudioBlockProcessResult{
        .didProcessGraph = true,
        .processedSamples = 0,
        .didReachScheduledStop = transportResult.didReachScheduledStop,
    };
  }

  sequenceStore.rt_processSequenceChanges(numSamples);
  automationSequenceStore.rt_processSequenceChanges(numSamples);

  const auto didProcessGraph =
      graphProcessor.rt_process(numSamples, audioProcessingConfigGeneration);

  const auto endTime = juce::Time::getHighResolutionTicks();
  // The worklet clock may fall back to wall time. Avoid negative CPU burden
  // if the system clock is adjusted backwards.
  const auto duration = juce::jmax<juce::int64>(0, endTime - startTime);
  const auto durationInSeconds = juce::Time::highResolutionTicksToSeconds(duration);
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

  const auto transportResult = transport.rt_endProcessingBlock();
  sequenceStore.rt_cleanupAfterBlock();

  return AudioBlockProcessResult{
      .didProcessGraph = didProcessGraph,
      .processedSamples = numSamples,
      .didReachScheduledStop = transportResult.didReachScheduledStop,
  };
}

} // namespace anthem
