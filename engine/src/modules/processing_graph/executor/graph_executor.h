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

#include <cstddef>
#include <juce_core/juce_core.h>
#include <memory>

#if JUCE_MAC
#include <juce_audio_basics/juce_audio_basics.h>
#endif

namespace anthem {

class RuntimeGraph;

class GraphExecutor {
private:
  class Impl;
public:
  struct ThreadConfig {
    int audioBlockSize = 0;
    double sampleRate = 0.0;
    size_t maxActiveWorkerThreadCount = 0;

    // Filled by GraphExecutor::prepare(). These are exposed here so the
    // platform-specific worker startup scopes can stay self-contained.
    size_t activeWorkerThreadCount = 0;
    size_t platformRealtimeWorkerThreadCount = 0;

#if JUCE_MAC
    juce::AudioWorkgroup macAudioWorkgroup;
#endif
  };

  class RuntimeState {
  public:
    ~RuntimeState();

    RuntimeState(const RuntimeState&) = delete;
    RuntimeState& operator=(const RuntimeState&) = delete;

    RuntimeState(RuntimeState&&) = delete;
    RuntimeState& operator=(RuntimeState&&) = delete;
  private:
    class Impl;

    RuntimeState(size_t readyNodeQueueCount, size_t readyNodeQueueCapacity);

    friend class GraphExecutor::Impl;
    friend class GraphExecutor;

    std::unique_ptr<Impl> impl;
  };

  GraphExecutor();
  ~GraphExecutor();

  GraphExecutor(const GraphExecutor&) = delete;
  GraphExecutor& operator=(const GraphExecutor&) = delete;

  GraphExecutor(GraphExecutor&&) = delete;
  GraphExecutor& operator=(GraphExecutor&&) = delete;

  void prepare(const ThreadConfig& threadConfig = {});
  std::unique_ptr<RuntimeState> createRuntimeStateForGraph(RuntimeGraph& runtimeGraph);
  void rt_processBlock(RuntimeGraph& runtimeGraph, RuntimeState& runtimeState, int numSamples);
private:
  std::unique_ptr<Impl> impl;
};

} // namespace anthem
