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

#include "generated/lib/model/processing_graph/processors/db_meter.h"
#include "modules/core/visualization/visualization_provider.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/processors/db_meter_accumulator.h"
#include "modules/util/ring_buffer.h"

#include <atomic>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace anthem {

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

class DbMeterProcessor : public Processor, public DbMeterProcessorModelBase {
private:
  std::vector<std::shared_ptr<DbMeterVisualizationProvider>> channelProviders;
  std::vector<std::string> registeredVisualizationIds;
  DbMeterAccumulator rt_accumulator;
  std::shared_ptr<std::atomic<int64_t>> rt_publishEverySamples;

  void syncVisualizationProviders();
  void unregisterVisualizationProviders();
public:
  DbMeterProcessor(const DbMeterProcessorModelImpl& _impl);
  ~DbMeterProcessor() override;

  DbMeterProcessor(const DbMeterProcessor&) = delete;
  DbMeterProcessor& operator=(const DbMeterProcessor&) = delete;

  DbMeterProcessor(DbMeterProcessor&&) noexcept = default;
  DbMeterProcessor& operator=(DbMeterProcessor&&) noexcept = default;

  void prepareToProcess() override;
  void process(NodeProcessContext& context, int numSamples) override;

  void initialize(
      std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) override;
};

} // namespace anthem
