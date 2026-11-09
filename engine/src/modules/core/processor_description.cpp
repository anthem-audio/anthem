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

#include "processor_description.h"

namespace anthem {

std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId,
    bool success,
    std::optional<std::string> error,
    std::optional<std::shared_ptr<ProcessingGraphNodePortConfiguration>> portConfiguration) {
  return std::make_shared<ProcessingGraphNodeInitializationResult>(
      ProcessingGraphNodeInitializationResult{
          .nodeId = nodeId,
          .success = success,
          .error = std::move(error),
          .portConfiguration = std::move(portConfiguration),
          .parameterValues =
              std::make_shared<std::vector<std::shared_ptr<ProcessingGraphParameterValue>>>(),
      });
}

std::shared_ptr<ProcessingGraphPortConfiguration> makePortConfiguration(
    const ProcessorPortConfiguration& portConfiguration) {
  return std::make_shared<ProcessingGraphPortConfiguration>(ProcessingGraphPortConfiguration{
      .id = portConfiguration.id,
      .name = portConfiguration.name,
      .channelCount = portConfiguration.channelCount,
      .parameterDefaultValue = portConfiguration.parameterDefaultValue,
      .parameterDisplayMode = portConfiguration.parameterDisplayMode,
      .parameterUnitLabel = portConfiguration.parameterUnitLabel,
      .parameterNormalizedVisualBaseline = portConfiguration.parameterNormalizedVisualBaseline,
  });
}

std::shared_ptr<std::vector<std::shared_ptr<ProcessingGraphPortConfiguration>>>
makePortConfigurationList(const std::vector<ProcessorPortConfiguration>& portConfigurations) {
  auto result = std::make_shared<std::vector<std::shared_ptr<ProcessingGraphPortConfiguration>>>();
  result->reserve(portConfigurations.size());

  for (const auto& portConfiguration : portConfigurations) {
    result->push_back(makePortConfiguration(portConfiguration));
  }

  return result;
}

std::shared_ptr<ProcessingGraphNodePortConfiguration> makeNodePortConfiguration(
    const ProcessorNodePortConfiguration& portConfiguration) {
  return std::make_shared<ProcessingGraphNodePortConfiguration>(
      ProcessingGraphNodePortConfiguration{
          .audioInputPorts = makePortConfigurationList(portConfiguration.audioInputPorts),
          .audioOutputPorts = makePortConfigurationList(portConfiguration.audioOutputPorts),
          .eventInputPorts = makePortConfigurationList(portConfiguration.eventInputPorts),
          .eventOutputPorts = makePortConfigurationList(portConfiguration.eventOutputPorts),
          .controlInputPorts = makePortConfigurationList(portConfiguration.controlInputPorts),
          .controlOutputPorts = makePortConfigurationList(portConfiguration.controlOutputPorts),
      });
}

std::shared_ptr<ProcessingGraphParameterValue> makeParameterValue(
    const ProcessorParameterValue& parameterValue) {
  return std::make_shared<ProcessingGraphParameterValue>(ProcessingGraphParameterValue{
      .controlPortId = parameterValue.controlPortId,
      .value = parameterValue.value,
      .displayText = parameterValue.displayText,
  });
}

std::shared_ptr<std::vector<std::shared_ptr<ProcessingGraphParameterValue>>> makeParameterValueList(
    const std::vector<ProcessorParameterValue>& parameterValues) {
  auto result = std::make_shared<std::vector<std::shared_ptr<ProcessingGraphParameterValue>>>();
  result->reserve(parameterValues.size());

  for (const auto& parameterValue : parameterValues) {
    result->push_back(makeParameterValue(parameterValue));
  }

  return result;
}

std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId, const ProcessorPrepareResult& prepareResult) {
  std::optional<std::shared_ptr<ProcessingGraphNodePortConfiguration>> portConfiguration =
      std::nullopt;

  if (prepareResult.portConfiguration.has_value()) {
    portConfiguration = makeNodePortConfiguration(*prepareResult.portConfiguration);
  }

  auto result = makeNodeInitializationResult(
      nodeId, prepareResult.success, prepareResult.error, std::move(portConfiguration));
  result->parameterValues = makeParameterValueList(prepareResult.parameterValues);
  return result;
}

} // namespace anthem
