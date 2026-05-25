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

#include "modules/processors/sequence_automation_provider.h"

#include <cmath>
#include <juce_core/juce_core.h>
#include <limits>

namespace anthem {

class SequenceAutomationProviderTest : public juce::UnitTest {
  using RuntimeState = SequenceAutomationProviderProcessor::RuntimeState;
  using RuntimeDependencies = SequenceAutomationProviderProcessor::RuntimeDependencies;

  static constexpr int64_t trackId = 11;
  static constexpr int64_t otherTrackId = 12;

  static AutomationSequenceSpan makeSpan(double start,
      double end,
      float startValue,
      float endValue,
      double sourceStartNormalized = 0.0,
      double sourceEndNormalized = 1.0) {
    return AutomationSequenceSpan{
        .startTick = start,
        .endTick = end,
        .startValue = startValue,
        .endValue = endValue,
        .curve = AutomationCurveType::smooth,
        .tension = 0.0,
        .sourceCurveStartNormalized = sourceStartNormalized,
        .sourceCurveEndNormalized = sourceEndNormalized,
    };
  }

  static void addTrack(AutomationSpanListCollection& sequence,
      int64_t sourceTrackId,
      std::initializer_list<AutomationSequenceSpan> spans,
      float initialValue = 0.0f) {
    auto* track = new AutomationSpanList();
    track->hasInitialValue = true;
    track->initialValue = initialValue;

    for (const auto& span : spans) {
      track->spans.push_back(span);
    }

    sequence.setTrack(sourceTrackId, track);
  }

  static RuntimeDependencies buildDependencies(const AutomationSpanListCollection* activeSequence) {
    return RuntimeDependencies{
        .rt_isPlaying = true,
        .rt_activeTrackId = std::nullopt,
        .rt_playhead = 0.0,
        .rt_loopStart = 0.0,
        .rt_loopEnd = std::numeric_limits<double>::infinity(),
        .rt_timingParams =
            sequencer_timing::TimingParams{
                .ticksPerQuarter = 4,
                .beatsPerMinute = 60.0,
                .sampleRate = 4.0,
            },
        .rt_activeSequence = activeSequence,
    };
  }

  static float sampleAt(const juce::AudioSampleBuffer& buffer, int sample) {
    return buffer.getReadPointer(0)[sample];
  }

  void expectSample(
      const juce::AudioSampleBuffer& buffer, int sample, float expected, const juce::String& text) {
    expect(std::fabs(sampleAt(buffer, sample) - expected) < 0.0001f, text);
  }
public:
  SequenceAutomationProviderTest() : juce::UnitTest("SequenceAutomationProviderTest", "Anthem") {}

  void runTest() override {
    testPlaybackOutputsEvaluatedAutomation();
    testStoppedTransportOutputsPlayheadValue();
    testActiveTrackUsesNoTrackAutomation();
    testMissingAutomationUsesEmptyValue();
    testClippedSourceCurveNormalizedRangeIsEvaluated();
  }

  void testPlaybackOutputsEvaluatedAutomation() {
    beginTest("Playback outputs evaluated automation values");

    AutomationSpanListCollection sequence;
    addTrack(sequence, trackId, {makeSpan(0.0, 4.0, 0.1f, 0.5f)}, 0.1f);

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    juce::AudioSampleBuffer buffer(1, 4);

    SequenceAutomationProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 0.0f, 4);

    expectSample(buffer, 0, 0.1f, "Sample 0 should use span start");
    expectSample(buffer, 1, 0.2f, "Sample 1 should interpolate");
    expectSample(buffer, 2, 0.3f, "Sample 2 should interpolate");
    expectSample(buffer, 3, 0.4f, "Sample 3 should interpolate");
  }

  void testStoppedTransportOutputsPlayheadValue() {
    beginTest("Stopped transport outputs the value at the current playhead");

    AutomationSpanListCollection sequence;
    addTrack(sequence, trackId, {makeSpan(0.0, 4.0, 0.1f, 0.5f)}, 0.1f);

    auto dependencies = buildDependencies(&sequence);
    dependencies.rt_isPlaying = false;
    dependencies.rt_playhead = 2.0;
    RuntimeState state;
    juce::AudioSampleBuffer buffer(1, 4);

    SequenceAutomationProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 0.0f, 4);

    for (int sample = 0; sample < 4; sample++) {
      expectSample(buffer, sample, 0.3f, "Stopped output should be constant");
    }
  }

  void testActiveTrackUsesNoTrackAutomation() {
    beginTest("Active track reads reserved no-track automation when available");

    AutomationSpanListCollection sequence;
    addTrack(sequence, trackId, {makeSpan(0.0, 4.0, 0.1f, 0.2f)}, 0.1f);
    addTrack(sequence, sequencer_track_ids::noTrack, {makeSpan(0.0, 4.0, 0.7f, 0.9f)}, 0.7f);

    auto dependencies = buildDependencies(&sequence);
    dependencies.rt_activeTrackId = trackId;
    RuntimeState state;
    juce::AudioSampleBuffer buffer(1, 1);

    SequenceAutomationProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 0.0f, 1);

    expectSample(buffer, 0, 0.7f, "No-track automation should override track automation");
  }

  void testMissingAutomationUsesEmptyValue() {
    beginTest("Missing automation uses the provider empty value");

    AutomationSpanListCollection sequence;
    addTrack(sequence, otherTrackId, {makeSpan(0.0, 4.0, 0.1f, 0.2f)}, 0.1f);

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    juce::AudioSampleBuffer buffer(1, 2);

    SequenceAutomationProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 0.42f, 2);

    expectSample(buffer, 0, 0.42f, "Missing track should use empty value");
    expectSample(buffer, 1, 0.42f, "Missing track should use empty value");
  }

  void testClippedSourceCurveNormalizedRangeIsEvaluated() {
    beginTest("Clipped source curve normalized range is evaluated");

    AutomationSpanListCollection sequence;
    addTrack(sequence, trackId, {makeSpan(0.0, 2.0, 0.0f, 1.0f, 0.5, 1.0)}, 0.5f);

    auto dependencies = buildDependencies(&sequence);
    RuntimeState state;
    juce::AudioSampleBuffer buffer(1, 2);

    SequenceAutomationProviderProcessor::rt_processBlock(
        state, dependencies, buffer, trackId, 0.0f, 2);

    expectSample(buffer, 0, 0.5f, "First sample should start halfway through source curve");
    expectSample(buffer, 1, 0.75f, "Second sample should continue through source curve");
  }
};

static SequenceAutomationProviderTest sequenceAutomationProviderTest;

} // namespace anthem
