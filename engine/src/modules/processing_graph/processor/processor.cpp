/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

#include "processor.h"

#include <cmath>
#include <stdexcept>
#include <utility>

namespace anthem {

Processor::Processor(Processor&& other) noexcept
  : name(std::move(other.name)), isPrepared(other.isPrepared.load()),
    hasRestoredProjectState(other.hasRestoredProjectState.load()),
    parameters(std::move(other.parameters)) {}

Processor& Processor::operator=(Processor&& other) noexcept {
  name = std::move(other.name);
  isPrepared = other.isPrepared.load();
  hasRestoredProjectState = other.hasRestoredProjectState.load();
  parameters = std::move(other.parameters);
  return *this;
}

void Processor::reconcileParameters(const ProcessorPrepareResult& result) {
  if (!result.portConfiguration)
    return;
  for (const auto& port : result.portConfiguration->controlInputPorts) {
    if (!port.parameterDefaultValue || parameters.contains(port.id))
      continue;
    double value = *port.parameterDefaultValue;
    for (const auto& reported : result.parameterValues)
      if (reported.controlPortId == port.id)
        value = reported.value;
    parameters.emplace(port.id, std::make_shared<ProcessorParameter>(static_cast<float>(value)));
  }
  parametersReconciled();
}

void Processor::restoreParameterValues(const std::map<int64_t, double>& values) {
  for (const auto& [id, value] : values) {
    parameters.try_emplace(id, std::make_shared<ProcessorParameter>(0.0f));
    if (const auto error = setParameterValue(id, value))
      throw std::runtime_error(*error);
  }
}

std::shared_ptr<ProcessorParameter> Processor::getParameter(int64_t id) const {
  const auto it = parameters.find(id);
  return it == parameters.end() ? nullptr : it->second;
}

std::vector<ProcessorParameterValue> Processor::getParameterValues() const {
  std::vector<ProcessorParameterValue> result;
  result.reserve(parameters.size());
  for (const auto& [id, parameter] : parameters) {
    const auto value = parameter->value.load(std::memory_order_relaxed);
    result.push_back(
        {.controlPortId = id, .value = value, .displayText = getParameterDisplayText(id, value)});
  }
  return result;
}

std::optional<std::string> Processor::setParameterValue(int64_t id, double requested) {
  const auto parameter = getParameter(id);
  if (!parameter)
    return "Processor parameter not found.";
  if (!std::isfinite(requested))
    return "Parameter value must be finite.";
  const auto value =
      normalizeParameterValue(id, juce::jlimit(0.0f, 1.0f, static_cast<float>(requested)));
  parameter->value.store(value, std::memory_order_relaxed);
  if ((parameter->controlRevision.load(std::memory_order_acquire) & 1) == 0)
    applyParameterValue(id, value);
  return std::nullopt;
}

bool ProcessorParameter::acceptChange(float requestedValue, uint64_t revision) noexcept {
  if ((revision & 1) != 0 || controlRevision.load(std::memory_order_acquire) != revision ||
      !std::isfinite(requestedValue))
    return false;
  value.store(juce::jlimit(0.0f, 1.0f, requestedValue), std::memory_order_relaxed);
  return true;
}

} // namespace anthem
