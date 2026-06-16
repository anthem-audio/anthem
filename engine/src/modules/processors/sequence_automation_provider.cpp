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

#include "sequence_automation_provider.h"

#include "modules/core/engine_runtime_services.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <algorithm>

namespace anthem {

namespace {
constexpr double linearCenterTransitionRate = 0.27;
constexpr double linearCenterWidth = 1.6;
constexpr double tensionScale = 15.0;
constexpr double positiveTensionPower = 2.2;
constexpr double linearTensionScale = 0.7;

double clampNormalized(double value) {
  return std::clamp(value, 0.0, 1.0);
}

float clampAutomationValue(float value) {
  return std::clamp(value, 0.0f, 1.0f);
}

double powPositive(double base, double exponent) {
  if (base <= 0.0) {
    return 0.0;
  }

  return std::pow(base, exponent);
}
} // namespace

SequenceAutomationProviderProcessor::SequenceAutomationProviderProcessor(
    const SequenceAutomationProviderProcessorModelImpl& _impl)
  : Processor("SequenceAutomationProvider"), SequenceAutomationProviderProcessorModelBase(_impl) {}

SequenceAutomationProviderProcessor::~SequenceAutomationProviderProcessor() {
  // Nothing to do here
}

const AutomationSpanList* SequenceAutomationProviderProcessor::rt_getSourceTrackAutomation(
    const RuntimeDependencies& dependencies, int64_t trackId) {
  if (dependencies.rt_activeSequence == nullptr) {
    return nullptr;
  }

  int64_t sourceTrackId = trackId;
  if (dependencies.rt_activeTrackId.has_value() &&
      dependencies.rt_activeTrackId.value() == trackId) {
    auto noTrackIter = dependencies.rt_activeSequence->tracks.find(sequencer_track_ids::noTrack);
    if (noTrackIter != dependencies.rt_activeSequence->tracks.end()) {
      sourceTrackId = sequencer_track_ids::noTrack;
    }
  }

  auto sourceTrackIter = dependencies.rt_activeSequence->tracks.find(sourceTrackId);
  if (sourceTrackIter == dependencies.rt_activeSequence->tracks.end()) {
    return nullptr;
  }

  return sourceTrackIter->second;
}

double SequenceAutomationProviderProcessor::rt_evaluateSmoothCurve(
    double normalizedX, double tension) {
  const auto g = [](double value) {
    return std::atan2(value * linearCenterTransitionRate * juce::MathConstants<double>::pi, 1.0) /
               juce::MathConstants<double>::pi +
           0.5;
  };

  const double scaledTension = tension * tensionScale;
  const double linearCenterInterpolation =
      1.0 -
      (g(scaledTension + linearCenterWidth) + (1.0 - g(scaledTension - linearCenterWidth)) - 1.0);

  double powValue = 0.0;
  if (scaledTension > 0.0) {
    powValue = powPositive(scaledTension / 2.0, positiveTensionPower);
  } else if (scaledTension < 0.0) {
    powValue = -powPositive(-scaledTension / 2.0, positiveTensionPower);
  }

  const double rawTension = powValue * linearCenterInterpolation +
                            linearTensionScale * scaledTension * (1.0 - linearCenterInterpolation);

  const double clampedX = clampNormalized(normalizedX);
  if (tension >= 0.0) {
    return powPositive(clampedX, rawTension + 1.0);
  }

  return 1.0 - powPositive(1.0 - clampedX, -rawTension + 1.0);
}

float SequenceAutomationProviderProcessor::rt_evaluateSpanAtNormalizedPosition(
    const AutomationSequenceSpan& span, double normalizedPosition) {
  double curveValue = 0.0;

  switch (span.curve) {
    case AutomationCurveType::smooth:
      curveValue = rt_evaluateSmoothCurve(normalizedPosition, span.tension);
      break;
    case AutomationCurveType::stairs:
    case AutomationCurveType::wave:
    case AutomationCurveType::hold:
      curveValue = 0.0;
      break;
  }

  return clampAutomationValue(
      static_cast<float>(span.startValue + curveValue * (span.endValue - span.startValue)));
}

void SequenceAutomationProviderProcessor::rt_findSpanIndexLinear(
    const AutomationSpanList* track, double tick, size_t& spanIndex, bool& hasSpanIndex) {
  spanIndex = 0;
  hasSpanIndex = false;

  if (track == nullptr || track->spans.empty() || tick < track->spans.front().startTick) {
    return;
  }

  size_t result = 0;
  while (result + 1 < track->spans.size() && tick >= track->spans[result + 1].startTick) {
    result++;
  }

  spanIndex = result;
  hasSpanIndex = true;
}

void SequenceAutomationProviderProcessor::rt_prepareSpanLookupState(
    RuntimeState& state, const AutomationSpanList* track, double loopStart, double loopEnd) {
  if (state.rt_cachedTrack != track) {
    state.rt_cachedTrack = track;
    state.rt_hasLastSpanIndex = false;
    state.rt_hasLastEvaluatedTick = false;
    state.rt_hasLoopPointCache = false;
  }

  if (track == nullptr || !track->hasInitialValue || track->spans.empty()) {
    state.rt_hasLastSpanIndex = false;
    state.rt_hasLoopPointCache = false;
    return;
  }

  if (state.rt_hasLoopPointCache && state.rt_cachedLoopStart == loopStart &&
      state.rt_cachedLoopEnd == loopEnd) {
    return;
  }

  state.rt_cachedLoopStart = loopStart;
  state.rt_cachedLoopEnd = loopEnd;
  state.rt_hasLoopPointCache = true;

  rt_findSpanIndexLinear(
      track, loopStart, state.rt_loopStartSpanIndex, state.rt_loopStartHasSpanIndex);
}

void SequenceAutomationProviderProcessor::rt_useLoopStartSpanIndex(RuntimeState& state) {
  if (!state.rt_hasLoopPointCache) {
    return;
  }

  state.rt_lastSpanIndex = state.rt_loopStartSpanIndex;
  state.rt_hasLastSpanIndex = state.rt_loopStartHasSpanIndex;
}

void SequenceAutomationProviderProcessor::rt_findSpanIndexAtTick(
    RuntimeState& state, const AutomationSpanList* track, double tick) {
  if (track == nullptr || track->spans.empty()) {
    state.rt_hasLastSpanIndex = false;
    return;
  }

  if (state.rt_hasLastEvaluatedTick && tick < state.rt_lastEvaluatedTick &&
      sequencer_timing::hasValidLoopRange(state.rt_cachedLoopStart, state.rt_cachedLoopEnd) &&
      tick >= state.rt_cachedLoopStart) {
    rt_useLoopStartSpanIndex(state);
  }

  if (!state.rt_hasLastSpanIndex) {
    if (tick < track->spans.front().startTick) {
      return;
    }

    state.rt_lastSpanIndex = 0;
    state.rt_hasLastSpanIndex = true;
  } else if (state.rt_lastSpanIndex >= track->spans.size() ||
             tick < track->spans[state.rt_lastSpanIndex].startTick) {
    rt_findSpanIndexLinear(track, tick, state.rt_lastSpanIndex, state.rt_hasLastSpanIndex);
    return;
  }

  while (state.rt_lastSpanIndex + 1 < track->spans.size() &&
         tick >= track->spans[state.rt_lastSpanIndex + 1].startTick) {
    state.rt_lastSpanIndex++;
  }
}

float SequenceAutomationProviderProcessor::rt_evaluateTrackAtTick(
    RuntimeState& state, const AutomationSpanList* track, double tick, float emptyValue) {
  if (track == nullptr || !track->hasInitialValue) {
    return clampAutomationValue(emptyValue);
  }

  if (track->spans.empty()) {
    return track->initialValue;
  }

  rt_findSpanIndexAtTick(state, track, tick);
  state.rt_lastEvaluatedTick = tick;
  state.rt_hasLastEvaluatedTick = true;

  if (!state.rt_hasLastSpanIndex) {
    return track->initialValue;
  }

  const auto& span = track->spans[state.rt_lastSpanIndex];
  if (tick >= span.startTick && tick < span.endTick) {
    double visibleNormalized = 0.0;
    if (std::isfinite(span.endTick) && span.endTick > span.startTick) {
      visibleNormalized = (tick - span.startTick) / (span.endTick - span.startTick);
    }

    const double sourceNormalized =
        span.sourceCurveStartNormalized +
        (span.sourceCurveEndNormalized - span.sourceCurveStartNormalized) *
            clampNormalized(visibleNormalized);

    return rt_evaluateSpanAtNormalizedPosition(span, sourceNormalized);
  }

  return span.endValue;
}

void SequenceAutomationProviderProcessor::rt_fillOutput(
    AudioBufferView targetBuffer, int sample, int numChannels, float value) {
  for (int channel = 0; channel < numChannels; channel++) {
    targetBuffer.setSample(channel, sample, value);
  }
}

void SequenceAutomationProviderProcessor::rt_processBlock(RuntimeState& state,
    const RuntimeDependencies& dependencies,
    AudioBufferView targetBuffer,
    int64_t trackId,
    float emptyValue,
    int numSamples) {
  const auto* trackAutomation = rt_getSourceTrackAutomation(dependencies, trackId);
  const int numChannels = targetBuffer.getNumChannels();
  rt_prepareSpanLookupState(
      state, trackAutomation, dependencies.rt_loopStart, dependencies.rt_loopEnd);

  if (!dependencies.rt_isPlaying) {
    const float value =
        rt_evaluateTrackAtTick(state, trackAutomation, dependencies.rt_playhead, emptyValue);
    for (int sample = 0; sample < numSamples; sample++) {
      rt_fillOutput(targetBuffer, sample, numChannels, value);
    }
    return;
  }

  for (int sample = 0; sample < numSamples; sample++) {
    const double tickDelta = sequencer_timing::sampleCountToTickDelta(
        static_cast<double>(sample), dependencies.rt_timingParams);
    const double tick = sequencer_timing::advancePlayheadByTickDelta(
        dependencies.rt_playhead, tickDelta, dependencies.rt_loopStart, dependencies.rt_loopEnd);
    const float value = rt_evaluateTrackAtTick(state, trackAutomation, tick, emptyValue);
    rt_fillOutput(targetBuffer, sample, numChannels, value);
  }
}

void SequenceAutomationProviderProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  complete(std::nullopt);
}

void SequenceAutomationProviderProcessor::process(NodeProcessContext& context, int numSamples) {
  auto outputControlBuffer = context.getOutputControlBuffer(
      SequenceAutomationProviderProcessorModelBase::controlOutputPortId);

  auto& engineRuntimeServices = context.rt_getEngineRuntimeServices();
  auto& transport = engineRuntimeServices.rt_getTransport();
  const auto* config = transport.rt_config;
  auto& automationSequenceStore = engineRuntimeServices.rt_getAutomationSequenceStore();

  const AutomationSpanListCollection* activeSequence = nullptr;
  if (config->activeSequenceId.has_value()) {
    auto& sequenceSnapshot = automationSequenceStore.rt_getSequences();
    auto activeSequenceIter = sequenceSnapshot.sequences.find(*config->activeSequenceId);
    if (activeSequenceIter != sequenceSnapshot.sequences.end()) {
      activeSequence = activeSequenceIter->second;
    }
  }

  RuntimeDependencies dependencies{
      .rt_isPlaying = config->isPlaying,
      .rt_activeTrackId = config->activeTrackId,
      .rt_playhead = transport.rt_playhead,
      .rt_loopStart = config->loopStart,
      .rt_loopEnd = config->loopEnd,
      .rt_timingParams = transport.rt_getTimingParams(),
      .rt_activeSequence = activeSequence,
  };

  rt_processBlock(rt_state,
      dependencies,
      outputControlBuffer,
      trackId(),
      clampAutomationValue(static_cast<float>(emptyValue())),
      numSamples);
}

} // namespace anthem
