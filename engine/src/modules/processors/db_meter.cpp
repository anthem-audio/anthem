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

#include "db_meter.h"

#include "modules/core/engine.h"
#include "modules/core/visualization/visualization_broker.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <algorithm>

namespace anthem {

std::optional<NumericVisualizationData> DbMeterVisualizationProvider::getTypedData() {
  return drainTimestampedVisualizationBuffer(valueBuffer);
}

void DbMeterVisualizationProvider::rt_pushValue(double value, int64_t sampleTimestamp) {
  valueBuffer.add(TimestampedVisualizationValue<double>{
      .sampleTimestamp = sampleTimestamp,
      .value = value,
  });
}

DbMeterProcessor::DbMeterProcessor(const DbMeterProcessorModelImpl& _impl)
  : Processor("DbMeter"), DbMeterProcessorModelBase(_impl),
    publishEverySamplesStorage(std::make_unique<std::atomic<int64_t>>(1)),
    rt_publishEverySamples(publishEverySamplesStorage.get()) {}

DbMeterProcessor::~DbMeterProcessor() {
  unregisterVisualizationProviders();
}

void DbMeterProcessor::initialize(
    std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) {
  DbMeterProcessorModelBase::initialize(selfModel, parentModel);

  rt_publishEverySamples->store(
      std::max<int64_t>(1, publishEverySamples()), std::memory_order_relaxed);

  addPublishEverySamplesObserver([this](int64_t newValue) {
    rt_publishEverySamples->store(std::max<int64_t>(1, newValue), std::memory_order_relaxed);
  });

  registerVisualizationProviders();
}

void DbMeterProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  auto* currentDevice = Engine::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);

  if (currentDevice == nullptr) {
    complete(ProcessorPrepareResult{
        .success = false,
        .error = std::string("No audio device is active."),
    });
    return;
  }

  size_t rt_channelCount = 0;

  if (currentDevice != nullptr) {
    rt_channelCount =
        static_cast<size_t>(currentDevice->getActiveOutputChannels().countNumberOfSetBits());
  }

  rt_accumulator.rt_prepare(rt_channelCount);

  rt_publishEverySamples->store(
      std::max<int64_t>(1, publishEverySamples()), std::memory_order_relaxed);

  complete(std::nullopt);
}

void DbMeterProcessor::process(NodeProcessContext& context, int numSamples) {
  if (visualizationProviders.empty() || numSamples <= 0) {
    return;
  }

  auto& audioInBuffer = context.getInputAudioBuffer(DbMeterProcessorModelBase::audioInputPortId);
  const int64_t publishEverySamples =
      std::max<int64_t>(1, rt_publishEverySamples->load(std::memory_order_relaxed));
  const int64_t blockStartSample = Engine::getInstance().transport->rt_sampleCounter;
  rt_accumulator.rt_processBlock(audioInBuffer,
      numSamples,
      blockStartSample,
      publishEverySamples,
      [this](size_t channelIndex, double valueDb, int64_t sampleTimestamp) {
        if (channelIndex >= visualizationProviders.size()) {
          return;
        }

        auto* provider = visualizationProviders[channelIndex].rt_getProvider();
        if (provider == nullptr) {
          return;
        }

        provider->rt_pushValue(valueDb, sampleTimestamp);
      });
}

void DbMeterProcessor::registerVisualizationProviders() {
  jassert(visualizationProviders.empty());
  visualizationProviders.clear();

  visualizationProviders.reserve(visualizationIds()->size());

  for (const auto& visualizationId : *visualizationIds()) {
    visualizationProviders.push_back(
        RegisteredVisualizationProvider<DbMeterVisualizationProvider>::registerDataProvider(
            visualizationId, std::make_unique<DbMeterVisualizationProvider>()));
  }
}

void DbMeterProcessor::unregisterVisualizationProviders() {
  for (auto& provider : visualizationProviders) {
    provider.release();
  }

  visualizationProviders.clear();
}
} // namespace anthem
