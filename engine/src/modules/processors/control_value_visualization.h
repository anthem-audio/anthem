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

#include "generated/lib/model/processing_graph/processors/control_value_visualization.h"
#include "modules/core/visualization/visualization_broker.h"
#include "modules/core/visualization/visualization_provider.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/processing_graph/runtime/audio_buffer_view.h"

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

namespace anthem {

class ControlValueVisualizationProvider
  : public TypedVisualizationDataProvider<double, VisualizationValueType::doubleValue> {
private:
  JUCE_LEAK_DETECTOR(ControlValueVisualizationProvider)

  LatestTimestampedVisualizationValue<double> latestValue;
public:
  std::optional<NumericVisualizationData> getTypedData() override;

  void rt_pushValue(double value, int64_t sampleTimestamp);
};

class ControlValueVisualizationProcessor : public Processor,
                                           public ControlValueVisualizationProcessorModelBase {
private:
  friend class ControlValueVisualizationProcessorTest;

  RegisteredVisualizationProvider<ControlValueVisualizationProvider> visualizationProvider;

  void registerVisualizationProvider();
  void unregisterVisualizationProvider();
public:
  ControlValueVisualizationProcessor(const ControlValueVisualizationProcessorModelImpl& _impl);
  ~ControlValueVisualizationProcessor() override;

  ControlValueVisualizationProcessor(const ControlValueVisualizationProcessor&) = delete;
  ControlValueVisualizationProcessor& operator=(const ControlValueVisualizationProcessor&) = delete;

  ControlValueVisualizationProcessor(ControlValueVisualizationProcessor&&) noexcept = default;
  ControlValueVisualizationProcessor& operator=(
      ControlValueVisualizationProcessor&&) noexcept = default;

  static std::optional<TimestampedVisualizationValue<double>> rt_getBlockValue(
      AudioBufferView inputBuffer, int numSamples, int64_t blockStartSample);

  void initialize(
      std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) override;
  void prepareToProcess(ProcessorPrepareCallback complete) override;
  void process(NodeProcessContext& context, int numSamples) override;
};

} // namespace anthem
