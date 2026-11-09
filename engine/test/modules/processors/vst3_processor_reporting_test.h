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

#include "allocation_tracker.h"
#include "modules/core/processor_state_snapshot.h"
#include "modules/processors/gain.h"
#include "modules/processors/vst3_processor.h"

#include <limits>

namespace anthem {

class VST3ProcessorReportingTest : public juce::UnitTest {
  using Kind = VST3Processor::PluginNotificationKind;

  void prepare(VST3Processor& processor, juce::AudioProcessorParameter& pluginParameter) {
    processor.reportingState = std::make_unique<VST3Processor::PluginReportingState>(processor);
    processor.parameterPortIdsByIndex = {900, -1};
    processor.parametersByPortId.emplace(900, &pluginParameter);
    ProcessorPrepareResult result{
        .portConfiguration = ProcessorNodePortConfiguration{
            .controlInputPorts = {{.id = 900, .parameterDefaultValue = 0.25}}}};
    processor.reconcileParameters(result);
    processor.reportingState->timer.stopTimer();
    processor.hasRestoredProjectState = true;
    processor.isPrepared = true;
  }
public:
  VST3ProcessorReportingTest() : juce::UnitTest("VST3 processor reporting", "Processors") {}

  void runTest() override {
    beginTest(
        "Callbacks retain gesture values and update saved state before notification delivery");
    juce::AudioParameterFloat pluginParameter(
        juce::ParameterID("test", 1), "Test", 0.0f, 1.0f, 0.25f);
    VST3Processor processor(VST3ProcessorModelImpl{.nodeId = 1, .vst3Path = ""});
    prepare(processor, pluginParameter);
    {
      test::AllocationScope allocations;
      processor.audioProcessorParameterChangeGestureBegin(nullptr, 0);
      processor.audioProcessorParameterChanged(nullptr, 0, 0.4f);
      processor.audioProcessorParameterChanged(nullptr, 0, 0.8f);
      processor.audioProcessorParameterChangeGestureEnd(nullptr, 0);
    }
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    ProcessorStateSnapshot snapshot(processor);
    GainProcessor restored(GainProcessorModelImpl{.nodeId = 2});
    snapshot.restore(restored);
    expectWithinAbsoluteError(restored.getParameter(900)->value.load(), 0.8f, 0.00001f);
    auto& notifications = processor.reportingState->notifications;
    for (const auto& [kind, value] : std::array{std::pair{Kind::gestureBegin, 0.25f},
             std::pair{Kind::value, 0.4f},
             std::pair{Kind::value, 0.8f},
             std::pair{Kind::gestureEnd, 0.8f}}) {
      const auto notification = notifications.tryPop();
      expect(notification.has_value());
      if (notification) {
        expect(notification->kind == kind);
        expectEquals(notification->portId, int64_t(900));
        expectWithinAbsoluteError(notification->value, value, 0.00001f);
      }
    }
    expect(!notifications.tryPop());

    beginTest("Invalid and controlled reports cannot change the saved base value");
    const auto parameter = processor.getParameter(900);
    parameter->rt_setControlled(true);
    {
      test::AllocationScope allocations;
      processor.audioProcessorParameterChanged(nullptr, 0, 0.1f);
      processor.audioProcessorParameterChangeGestureBegin(nullptr, 0);
      processor.audioProcessorParameterChanged(nullptr, -1, 0.1f);
      processor.audioProcessorParameterChanged(nullptr, 1, 0.1f);
      processor.audioProcessorParameterChanged(nullptr, 900, 0.1f);
    }
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    expectWithinAbsoluteError(parameter->value.load(), 0.8f, 0.00001f);
    expect(!notifications.tryPop());
    parameter->rt_setControlled(false);
    processor.audioProcessorParameterChanged(nullptr, 0, std::numeric_limits<float>::quiet_NaN());
    expect(!notifications.tryPop());

    beginTest("Program callbacks update base values without allocating or formatting text");
    pluginParameter = 0.6f;
    {
      test::AllocationScope allocations;
      processor.audioProcessorChanged(
          nullptr, juce::AudioProcessorListener::ChangeDetails{}.withProgramChanged(true));
    }
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    expectWithinAbsoluteError(parameter->value.load(), 0.6f, 0.00001f);
    const auto programChange = notifications.tryPop();
    expect(programChange && programChange->kind == Kind::processorChanged);

    beginTest("Overflow preserves authoritative values and requests gesture recovery");
    for (int i = 0; i < 1100; ++i)
      processor.audioProcessorParameterChanged(nullptr, 0, 0.9f);
    expect(notifications.takeRecoveryRequest());
    expectWithinAbsoluteError(parameter->value.load(), 0.9f, 0.00001f);
    notifications.beginRecovery();
    notifications.endRecovery();
    expect(!notifications.tryPop());
    processor.audioProcessorParameterChanged(nullptr, 0, 0.7f);
    expect(notifications.tryPop().has_value());

    beginTest("Repreparation retains immutable bindings and suppresses parameter reports");
    const auto* bindings = processor.reportingState->bindings->parameters.data();
    processor.isPrepared = false;
    processor.audioProcessorParameterChanged(nullptr, 0, 0.1f);
    expectWithinAbsoluteError(parameter->value.load(), 0.7f, 0.00001f);
    processor.parametersReconciled();
    processor.reportingState->timer.stopTimer();
    expect(processor.reportingState->bindings->parameters.data() == bindings);
    processor.isPrepared = true;
    processor.audioProcessorParameterChanged(nullptr, 0, 0.5f);
    expectWithinAbsoluteError(parameter->value.load(), 0.5f, 0.00001f);

    beginTest("A changed parameter layout requires reload without replacing active bindings");
    processor.isPrepared = false;
    processor.parameterPortIdsByIndex[0] = 901;
    bool rejected = false;
    try {
      processor.parametersReconciled();
    } catch (const std::runtime_error&) {
      rejected = true;
    }
    expect(rejected);
    expect(processor.reportingState->bindings->parameters.data() == bindings);
    expect(processor.reportingState->bindings->forJuceIndex(0)->parameter == parameter.get());
  }
};

inline VST3ProcessorReportingTest vst3ProcessorReportingTest;

} // namespace anthem
