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

#include <algorithm>
#include <cmath>

#include "modules/core/anthem.h"
#include "modules/core/visualization/visualization_broker.h"
#include "modules/processing_graph/compiler/anthem_process_context.h"

std::optional<NumericVisualizationData>
DbMeterVisualizationProvider::getTypedData() {
  return drainTimestampedVisualizationBuffer(valueBuffer);
}

void DbMeterVisualizationProvider::rt_pushValue(
  double value,
  int64_t sampleTimestamp
) {
  valueBuffer.add(
    TimestampedVisualizationValue<double> {
      .sampleTimestamp = sampleTimestamp,
      .value = value,
    }
  );
}

DbMeterProcessor::DbMeterProcessor(const DbMeterProcessorModelImpl& _impl)
  : AnthemProcessor("DbMeter"),
    DbMeterProcessorModelBase(_impl),
    rt_publishEverySamples(std::make_shared<std::atomic<int64_t>>(1)) {}

DbMeterProcessor::~DbMeterProcessor() {
  unregisterVisualizationProviders();
}

void DbMeterProcessor::initialize(
  std::shared_ptr<AnthemModelBase> selfModel,
  std::shared_ptr<AnthemModelBase> parentModel
) {
  DbMeterProcessorModelBase::initialize(selfModel, parentModel);

  rt_publishEverySamples->store(
    std::max<int64_t>(1, publishEverySamples()),
    std::memory_order_relaxed
  );

  addPublishEverySamplesObserver([this](int64_t newValue) {
    rt_publishEverySamples->store(
      std::max<int64_t>(1, newValue),
      std::memory_order_relaxed
    );
  });

  syncVisualizationProviders();
}

void DbMeterProcessor::prepareToProcess() {
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);

  rt_samplesSinceLastPublish = 0;
  rt_channelPeakLinear.clear();

  if (currentDevice != nullptr) {
    const auto rt_channelCount =
      static_cast<size_t>(currentDevice->getActiveOutputChannels().countNumberOfSetBits());
    rt_channelPeakLinear.assign(rt_channelCount, 0.0f);
  }

  rt_publishEverySamples->store(
    std::max<int64_t>(1, publishEverySamples()),
    std::memory_order_relaxed
  );
}

void DbMeterProcessor::process(AnthemProcessContext& context, int numSamples) {
  if (channelProviders.empty() || numSamples <= 0) {
    return;
  }

  auto& audioInBuffer =
    context.getInputAudioBuffer(DbMeterProcessorModelBase::audioInputPortId);
  const int channelCount = audioInBuffer.getNumChannels();

  if (channelCount <= 0) {
    return;
  }

  if (rt_channelPeakLinear.size() != static_cast<size_t>(channelCount)) {
    jassertfalse;
    return;
  }

  const int64_t publishEverySamples =
    std::max<int64_t>(1, rt_publishEverySamples->load(std::memory_order_relaxed));
  const int64_t blockStartSample =
    Anthem::getInstance().transport->rt_sampleCounter;

  for (int sampleIndex = 0; sampleIndex < numSamples; ++sampleIndex) {
    for (int channelIndex = 0; channelIndex < channelCount; ++channelIndex) {
      const float absoluteSample = std::abs(
        audioInBuffer.getSample(channelIndex, sampleIndex)
      );
      rt_channelPeakLinear[static_cast<size_t>(channelIndex)] = std::max(
        rt_channelPeakLinear[static_cast<size_t>(channelIndex)],
        absoluteSample
      );
    }

    rt_samplesSinceLastPublish++;

    if (rt_samplesSinceLastPublish >= publishEverySamples) {
      publishCurrentWindow(
        channelCount,
        blockStartSample + static_cast<int64_t>(sampleIndex) + 1
      );
      rt_samplesSinceLastPublish = 0;
    }
  }
}

void DbMeterProcessor::syncVisualizationProviders() {
  unregisterVisualizationProviders();

  channelProviders.clear();
  registeredVisualizationIds.clear();

  channelProviders.reserve(visualizationIds()->size());
  registeredVisualizationIds.reserve(visualizationIds()->size());

  for (const auto& visualizationId : *visualizationIds()) {
    auto provider = std::make_shared<DbMeterVisualizationProvider>();
    VisualizationBroker::getInstance().registerDataProvider(
      visualizationId,
      provider
    );

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

void DbMeterProcessor::publishCurrentWindow(
  int channelCount,
  int64_t sampleTimestamp
) {
  const size_t providerCount = std::min(
    channelProviders.size(),
    static_cast<size_t>(channelCount)
  );

  for (size_t channelIndex = 0; channelIndex < providerCount; ++channelIndex) {
    auto& provider = channelProviders[channelIndex];
    if (provider == nullptr) {
      continue;
    }

    provider->rt_pushValue(
      peakLinearToDb(rt_channelPeakLinear[channelIndex]),
      sampleTimestamp
    );
  }

  std::fill(rt_channelPeakLinear.begin(), rt_channelPeakLinear.end(), 0.0f);
}
