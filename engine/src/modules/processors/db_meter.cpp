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
#include "modules/processing_graph/compiler/node_process_context.h"

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
    rt_publishEverySamples(std::make_shared<std::atomic<int64_t>>(1)) {}

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

  syncVisualizationProviders();
}

void DbMeterProcessor::prepareToProcess() {
  auto* currentDevice = Engine::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);

  size_t rt_channelCount = 0;

  if (currentDevice != nullptr) {
    rt_channelCount =
        static_cast<size_t>(currentDevice->getActiveOutputChannels().countNumberOfSetBits());
  }

  rt_accumulator.rt_prepare(rt_channelCount);

  rt_publishEverySamples->store(
      std::max<int64_t>(1, publishEverySamples()), std::memory_order_relaxed);
}

void DbMeterProcessor::process(NodeProcessContext& context, int numSamples) {
  if (channelProviders.empty() || numSamples <= 0) {
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
        if (channelIndex >= channelProviders.size()) {
          return;
        }

        auto& provider = channelProviders[channelIndex];
        if (provider == nullptr) {
          return;
        }

        provider->rt_pushValue(valueDb, sampleTimestamp);
      });
}

void DbMeterProcessor::syncVisualizationProviders() {
  unregisterVisualizationProviders();

  channelProviders.clear();
  registeredVisualizationIds.clear();

  channelProviders.reserve(visualizationIds()->size());
  registeredVisualizationIds.reserve(visualizationIds()->size());

  for (const auto& visualizationId : *visualizationIds()) {
    auto provider = std::make_shared<DbMeterVisualizationProvider>();
    VisualizationBroker::getInstance().registerDataProvider(visualizationId, provider);

    channelProviders.push_back(provider);
    registeredVisualizationIds.push_back(visualizationId);
  }
}

void DbMeterProcessor::unregisterVisualizationProviders() {
  for (const auto& visualizationId : registeredVisualizationIds) {
    VisualizationBroker::getInstance().unregisterDataProvider(visualizationId);
  }

  registeredVisualizationIds.clear();
  channelProviders.clear();
}
} // namespace anthem
