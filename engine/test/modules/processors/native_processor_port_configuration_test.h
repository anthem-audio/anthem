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

#include "modules/processors/balance.h"
#include "modules/processors/gain_parameter_mapping.h"
#include "modules/processors/utility.h"

#include <juce_core/juce_core.h>

namespace anthem {

class NativeProcessorPortConfigurationTest : public juce::UnitTest {
public:
  NativeProcessorPortConfigurationTest()
    : juce::UnitTest("Native processor port preparation", "Processors") {}

  void runTest() override {
    beginTest("Utility preparation supplies its factory metadata without UI state");
    UtilityProcessor utility(UtilityProcessorModelImpl{.nodeId = 1});
    std::optional<ProcessorPrepareResult> result;
    utility.prepareToProcess([&](auto prepared) { result = std::move(prepared); });
    expect(result.has_value() && result->success && result->portConfiguration.has_value());
    if (!result.has_value() || !result->portConfiguration.has_value())
      return;
    const auto& config = *result->portConfiguration;
    expectEquals(static_cast<int>(config.audioInputPorts.size()), 1);
    expectEquals(config.audioInputPorts[0].id, UtilityProcessor::audioInputPortId);
    expectEquals(config.audioInputPorts[0].channelCount.value(), int64_t(2));
    expectEquals(config.audioOutputPorts[0].id, UtilityProcessor::audioOutputPortId);
    const auto& gain = config.controlInputPorts[0];
    expectEquals(gain.id, UtilityProcessor::gainPortId);
    expectEquals(gain.parameterDefaultValue.value(), double(kGainParameterZeroDbNormalized));
    expect(gain.parameterDisplayMode == std::optional<std::string>("gainDb"));
    expect(gain.parameterUnitLabel == std::optional<std::string>("dB"));
    const auto& pan = config.controlInputPorts[1];
    expectEquals(pan.id, UtilityProcessor::balancePortId);
    expectEquals(pan.parameterDefaultValue.value(), 0.5);
    expect(pan.parameterDisplayMode == std::optional<std::string>("pan"));

    beginTest("Balance preparation supplies fixed stereo ports and neutral pan");
    BalanceProcessor balance(BalanceProcessorModelImpl{.nodeId = 2});
    balance.prepareToProcess([&](auto prepared) { result = std::move(prepared); });
    expect(result.has_value() && result->success && result->portConfiguration.has_value());
    if (!result.has_value() || !result->portConfiguration.has_value())
      return;
    const auto& balanceConfig = *result->portConfiguration;
    expectEquals(balanceConfig.audioInputPorts[0].id, BalanceProcessor::audioInputPortId);
    expectEquals(balanceConfig.audioOutputPorts[0].id, BalanceProcessor::audioOutputPortId);
    expectEquals(balanceConfig.audioOutputPorts[0].channelCount.value(), int64_t(2));
    expectEquals(balanceConfig.controlInputPorts[0].id, BalanceProcessor::balancePortId);
    expectEquals(balanceConfig.controlInputPorts[0].parameterDefaultValue.value(), 0.5);
  }
};

inline NativeProcessorPortConfigurationTest nativeProcessorPortConfigurationTest;

} // namespace anthem
