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

#pragma once

#include <atomic>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "generated/lib/model/processing_graph/processors/db_meter.h"
#include "modules/core/visualization/visualization_provider.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/util/ring_buffer.h"

#include "bw_math.h"

class DbMeterVisualizationProvider
  : public TypedVisualizationDataProvider<double, VisualizationValueType::doubleValue> {
private:
  JUCE_LEAK_DETECTOR(DbMeterVisualizationProvider)

  RingBuffer<TimestampedVisualizationValue<double>, 2048> valueBuffer;

public:
  DbMeterVisualizationProvider()
    : valueBuffer(RingBuffer<TimestampedVisualizationValue<double>, 2048>()) {}

  std::optional<NumericVisualizationData> getTypedData() override;

  void rt_pushValue(double value, int64_t sampleTimestamp);
};

class DbMeterProcessor : public AnthemProcessor, public DbMeterProcessorModelBase {
private:
  std::vector<std::shared_ptr<DbMeterVisualizationProvider>> channelProviders;
  std::vector<std::string> registeredVisualizationIds;
  std::vector<float> rt_channelPeakLinear;
  std::shared_ptr<std::atomic<int64_t>> rt_publishEverySamples;
  int64_t rt_samplesSinceLastPublish = 0;

  void syncVisualizationProviders();
  void unregisterVisualizationProviders();
  void rt_publishCurrentWindow(int channelCount, int64_t sampleTimestamp);

  static double peakLinearToDb(float peakLinear) {
    if (peakLinear <= 0.0f) {
      return -600.0;
    }

    return static_cast<double>(bw_lin2dBf(peakLinear));
  }

public:
  DbMeterProcessor(const DbMeterProcessorModelImpl& _impl);
  ~DbMeterProcessor() override;

  DbMeterProcessor(const DbMeterProcessor&) = delete;
  DbMeterProcessor& operator=(const DbMeterProcessor&) = delete;

  DbMeterProcessor(DbMeterProcessor&&) noexcept = default;
  DbMeterProcessor& operator=(DbMeterProcessor&&) noexcept = default;

  void prepareToProcess() override;
  void process(AnthemNodeProcessContext& context, int numSamples) override;

  void initialize(
    std::shared_ptr<AnthemModelBase> selfModel,
    std::shared_ptr<AnthemModelBase> parentModel
  ) override;
};
