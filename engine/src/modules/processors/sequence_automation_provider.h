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

#include "generated/lib/model/processing_graph/processors/sequence_automation_provider.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"
#include "modules/sequencer/runtime/transport.h"

#include <cmath>
#include <cstddef>
#include <juce_audio_basics/juce_audio_basics.h>
#include <limits>
#include <optional>

namespace anthem {

class NodeProcessContext;

class SequenceAutomationProviderProcessor : public Processor,
                                            public SequenceAutomationProviderProcessorModelBase {
private:
  friend class SequenceAutomationProviderTest;

  struct RuntimeDependencies {
    bool rt_isPlaying = false;
    std::optional<int64_t> rt_activeTrackId;
    double rt_playhead = 0.0;
    double rt_loopStart = 0.0;
    double rt_loopEnd = std::numeric_limits<double>::infinity();
    sequencer_timing::TimingParams rt_timingParams{};
    const AutomationSpanListCollection* rt_activeSequence = nullptr;
  };

  struct RuntimeState {
    const AutomationSpanList* rt_cachedTrack = nullptr;

    size_t rt_lastSpanIndex = 0;
    bool rt_hasLastSpanIndex = false;

    double rt_lastEvaluatedTick = 0.0;
    bool rt_hasLastEvaluatedTick = false;

    double rt_cachedLoopStart = 0.0;
    double rt_cachedLoopEnd = std::numeric_limits<double>::infinity();
    size_t rt_loopStartSpanIndex = 0;
    bool rt_loopStartHasSpanIndex = false;
    bool rt_hasLoopPointCache = false;
  };

  RuntimeState rt_state;

  static const AutomationSpanList* rt_getSourceTrackAutomation(
      const RuntimeDependencies& dependencies, int64_t trackId);

  static double rt_evaluateSmoothCurve(double normalizedX, double tension);
  static float rt_evaluateSpanAtNormalizedPosition(
      const AutomationSequenceSpan& span, double normalizedPosition);
  static void rt_findSpanIndexLinear(
      const AutomationSpanList* track, double tick, size_t& spanIndex, bool& hasSpanIndex);
  static void rt_prepareSpanLookupState(
      RuntimeState& state, const AutomationSpanList* track, double loopStart, double loopEnd);
  static void rt_useLoopStartSpanIndex(RuntimeState& state);
  static void rt_findSpanIndexAtTick(
      RuntimeState& state, const AutomationSpanList* track, double tick);
  static float rt_evaluateTrackAtTick(
      RuntimeState& state, const AutomationSpanList* track, double tick, float emptyValue);
  static void rt_fillOutput(
      juce::AudioSampleBuffer& targetBuffer, int sample, int numChannels, float value);

  static void rt_processBlock(RuntimeState& state,
      const RuntimeDependencies& dependencies,
      juce::AudioSampleBuffer& targetBuffer,
      int64_t trackId,
      float emptyValue,
      int numSamples);
public:
  SequenceAutomationProviderProcessor(const SequenceAutomationProviderProcessorModelImpl& _impl);
  ~SequenceAutomationProviderProcessor() override;

  SequenceAutomationProviderProcessor(const SequenceAutomationProviderProcessor&) = delete;
  SequenceAutomationProviderProcessor& operator=(
      const SequenceAutomationProviderProcessor&) = delete;

  SequenceAutomationProviderProcessor(SequenceAutomationProviderProcessor&&) noexcept = default;
  SequenceAutomationProviderProcessor& operator=(
      SequenceAutomationProviderProcessor&&) noexcept = default;

  void prepareToProcess(ProcessorPrepareCallback complete) override;
  void process(NodeProcessContext& context, int numSamples) override;
};

} // namespace anthem
