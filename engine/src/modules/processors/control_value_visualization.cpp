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

#include "control_value_visualization.h"

#include "modules/core/engine.h"
#include "modules/core/visualization/visualization_broker.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <algorithm>
#include <cmath>

namespace anthem {

std::optional<NumericVisualizationData> ControlValueVisualizationProvider::getTypedData() {
  return latestValue.drainLatest();
}

void ControlValueVisualizationProvider::rt_pushValue(double value, int64_t sampleTimestamp) {
  latestValue.rt_set(value, sampleTimestamp);
}

ControlValueVisualizationProcessor::ControlValueVisualizationProcessor(
    const ControlValueVisualizationProcessorModelImpl& _impl)
  : Processor("ControlValueVisualization"), ControlValueVisualizationProcessorModelBase(_impl) {}

ControlValueVisualizationProcessor::~ControlValueVisualizationProcessor() {
  unregisterVisualizationProvider();
}

void ControlValueVisualizationProcessor::initialize(
    std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) {
  ControlValueVisualizationProcessorModelBase::initialize(selfModel, parentModel);

  registerVisualizationProvider();
}

void ControlValueVisualizationProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  complete(std::nullopt);
}

std::optional<TimestampedVisualizationValue<double>>
ControlValueVisualizationProcessor::rt_getBlockValue(
    const juce::AudioSampleBuffer* inputBuffer, int numSamples, int64_t blockStartSample) {
  if (inputBuffer == nullptr || numSamples <= 0 || inputBuffer->getNumChannels() <= 0) {
    return std::nullopt;
  }

  const int availableSamples = std::min(numSamples, inputBuffer->getNumSamples());
  if (availableSamples <= 0) {
    return std::nullopt;
  }

  const int latestSampleIndex = availableSamples - 1;
  const double rawValue = static_cast<double>(inputBuffer->getReadPointer(0)[latestSampleIndex]);
  if (!std::isfinite(rawValue)) {
    return std::nullopt;
  }

  return TimestampedVisualizationValue<double>{
      .sampleTimestamp = blockStartSample + availableSamples,
      .value = std::clamp(rawValue, 0.0, 1.0),
  };
}

void ControlValueVisualizationProcessor::process(NodeProcessContext& context, int numSamples) {
  auto* inputBuffer = context.getInputControlBuffer(
      ControlValueVisualizationProcessorModelBase::controlInputPortId);
  const int64_t blockStartSample = Engine::getInstance().transport->rt_sampleCounter;
  auto value = rt_getBlockValue(inputBuffer, numSamples, blockStartSample);

  auto* provider = visualizationProvider.rt_getProvider();
  if (value.has_value() && provider != nullptr) {
    provider->rt_pushValue(value->value, value->sampleTimestamp);
  }
}

void ControlValueVisualizationProcessor::registerVisualizationProvider() {
  if (visualizationId().empty()) {
    return;
  }

  jassert(visualizationProvider.rt_getProvider() == nullptr);
  visualizationProvider =
      RegisteredVisualizationProvider<ControlValueVisualizationProvider>::registerDataProvider(
          visualizationId(), std::make_unique<ControlValueVisualizationProvider>());
}

void ControlValueVisualizationProcessor::unregisterVisualizationProvider() {
  visualizationProvider.release();
}

} // namespace anthem
