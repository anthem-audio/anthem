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

#pragma once

#include "modules/processing_graph/runtime/node_processing_state.h"

#include <atomic>
#include <cstdint>
#include <functional>
#include <juce_core/juce_core.h>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace anthem {

class GraphNode;
class NodeProcessContext;
class GraphProcessor;

struct ProcessorPortConfiguration {
  int64_t id;
  std::optional<std::string> name = std::nullopt;
  std::optional<int64_t> channelCount = std::nullopt;
  std::optional<double> parameterDefaultValue = std::nullopt;
  std::optional<std::string> parameterDisplayMode = std::nullopt;
  std::optional<std::string> parameterUnitLabel = std::nullopt;
  double parameterNormalizedVisualBaseline = 0.0;
};

struct ProcessorParameterValue {
  int64_t controlPortId;
  double value;
  std::optional<std::string> displayText = std::nullopt;
};

struct ProcessorNodePortConfiguration {
  std::vector<ProcessorPortConfiguration> audioInputPorts;
  std::vector<ProcessorPortConfiguration> audioOutputPorts;
  std::vector<ProcessorPortConfiguration> eventInputPorts;
  std::vector<ProcessorPortConfiguration> eventOutputPorts;
  std::vector<ProcessorPortConfiguration> controlInputPorts;
  std::vector<ProcessorPortConfiguration> controlOutputPorts;
};

struct ProcessorPrepareResult {
  bool success = true;
  std::optional<std::string> error = std::nullopt;
  std::optional<ProcessorNodePortConfiguration> portConfiguration = std::nullopt;
  std::vector<ProcessorParameterValue> parameterValues;
};

// Base settings outlive compiled graphs. Control ownership is recorded at the
// processing boundary so delayed plugin reports cannot become base-value edits.
struct ProcessorParameter {
  static_assert(std::atomic<float>::is_always_lock_free);
  static_assert(std::atomic<uint64_t>::is_always_lock_free);
  explicit ProcessorParameter(float value) : value(value) {}
  std::atomic<float> value;
  std::atomic<uint64_t> controlRevision{0};

  void rt_setControlled(bool controlled) {
    const auto previous = controlRevision.load(std::memory_order_relaxed);
    if (static_cast<bool>(previous & 1) != controlled)
      controlRevision.store(previous + 1, std::memory_order_release);
  }

  // May be called by a plugin on either its processing or editor thread. Only
  // reports from the same uncontrolled period may update the base setting.
  bool acceptChange(float requestedValue, uint64_t revision) noexcept;
};

// Processors may complete preparation synchronously or asynchronously.
// Successful preparation must include the processor's port configuration.
// Descriptions come from the processor, independently of cached UI metadata.
using ProcessorPrepareCallback = std::function<void(std::optional<ProcessorPrepareResult>)>;

// This class is used to process audio, event and control data. It can produce
// and/or consume any of these data types.
//
// This serves as a base class for internal and external plugins, but also for
// several internal processing modules that interact with the processing graph.
class Processor {
public:
  static_assert(std::atomic<bool>::is_always_lock_free);
  // The name of the processor.
  std::string name;

  Processor(std::string name) : name(name) {}

  // Model decoding moves processors into their final instances before preparation.
  Processor(Processor&& other) noexcept;
  Processor& operator=(Processor&& other) noexcept;

  virtual ~Processor() = default;

  // Called on the JUCE message thread to initialize the processor.
  //
  // Note that this is called after a processing config is active, so timing and
  // buffer layout information can be queried at this point.
  virtual void prepareToProcess(ProcessorPrepareCallback complete) = 0;

  // This flag must be set after prepareToProcess() is called. It is set by the
  // caller, not by the processor itself. Plugin callbacks can read readiness
  // from other threads.
  std::atomic<bool> isPrepared{false};

  // Instance state is restored once per processor lifetime. Audio-session
  // re-preparation must retain the live state rather than replaying a saved blob.
  std::atomic<bool> hasRestoredProjectState{false};

  // This method is called by the processing graph to process audio, event and
  // control data. It is called once per processing block. Processors with audio
  // output ports must fully replace every sample in each output buffer.
  virtual void process(NodeProcessContext& context, int numSamples) = 0;

  bool rt_tryAcquireProcessingAccess() noexcept {
    return processingState->rt_tryAcquireProcessingAccess();
  }
  void rt_releaseProcessingAccess() noexcept {
    processingState->rt_releaseProcessingAccess();
  }

  // Reconcile discovered parameters without replacing existing base settings.
  void reconcileParameters(const ProcessorPrepareResult& result);
  void restoreParameterValues(const std::map<int64_t, double>& values);
  std::shared_ptr<ProcessorParameter> getParameter(int64_t id) const;
  std::vector<ProcessorParameterValue> getParameterValues() const;
  std::optional<std::string> setParameterValue(int64_t id, double value);

  virtual std::optional<std::string> getParameterDisplayText(int64_t, float) const {
    return std::nullopt;
  }

  // Processor-specific state supplements the common base parameter values.
  // Gets the state of the processor
  virtual void getState(juce::MemoryBlock& /*target*/) {}

  // Loads the state of the processor from a value exported by getState()
  virtual void setState(const juce::MemoryBlock& /*state*/) {}
protected:
  // Called on the message thread after common parameter storage is established,
  // before callbacks and audio processing are allowed to use the processor.
  virtual void parametersReconciled() {}

  virtual float normalizeParameterValue(int64_t, float value) const {
    return value;
  }
  virtual void applyParameterValue(int64_t, float) {}
private:
  friend class GraphProcessor;

  // Pause requests go through the graph processor's special-node policy.
  std::shared_ptr<NodeProcessingPause> pauseProcessing() {
    return std::make_shared<NodeProcessingPause>(processingState);
  }
  std::map<int64_t, std::shared_ptr<ProcessorParameter>> parameters;
  std::shared_ptr<NodeProcessingState> processingState = std::make_shared<NodeProcessingState>();
};

} // namespace anthem
