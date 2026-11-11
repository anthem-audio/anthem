/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "global_visualization_sources.h"

#include "modules/sequencer/runtime/transport.h"

#include <algorithm>
#include <cmath>

namespace anthem {

namespace {
constexpr double playheadUpdateIntervalMs = 5.0;
constexpr double cpuAggregationWindowMs = 500.0;

int64_t samplesForDuration(double sampleRate, double durationMs) {
  jassert(sampleRate > 0.0);
  return std::max<int64_t>(1, static_cast<int64_t>(std::llround(sampleRate * durationMs / 1000.0)));
}

int64_t alignSampleTimestampToBlock(
    int64_t sampleTimestamp, int64_t blockStartSample, int64_t samplesPerStep) {
  if (sampleTimestamp >= blockStartSample) {
    return sampleTimestamp;
  }

  const auto samplesBehind = blockStartSample - sampleTimestamp;
  const auto intervalsBehind = (samplesBehind + samplesPerStep - 1) / samplesPerStep;
  return sampleTimestamp + intervalsBehind * samplesPerStep;
}
} // namespace

std::optional<NumericVisualizationData> CpuVisualizationProvider::getTypedData() {
  return drainTimestampedVisualizationBuffer(cpuBurdenBuffer);
}

void CpuVisualizationProvider::rt_updateCpuBurden(
    double newCpuBurden, int64_t blockStartSample, int numSamples, double sampleRate) {
  if (sampleRate <= 0.0 || numSamples <= 0) {
    jassertfalse;
    return;
  }

  const auto samplesPerWindow = samplesForDuration(sampleRate, cpuAggregationWindowMs);
  if (rt_sampleRate != sampleRate || rt_samplesPerWindow != samplesPerWindow) {
    rt_sampleRate = sampleRate;
    rt_samplesPerWindow = samplesPerWindow;
    rt_nextWindowEndSample = blockStartSample + samplesPerWindow;
    rt_windowMaxCpuBurden = 0.0;
    rt_hasWindowCpuBurden = false;
  }

  const auto blockEndSample = blockStartSample + static_cast<int64_t>(numSamples);
  rt_windowMaxCpuBurden =
      rt_hasWindowCpuBurden ? std::max(rt_windowMaxCpuBurden, newCpuBurden) : newCpuBurden;
  rt_hasWindowCpuBurden = true;

  while (blockEndSample >= rt_nextWindowEndSample) {
    cpuBurdenBuffer.add(TimestampedVisualizationValue<double>{
        .sampleTimestamp = rt_nextWindowEndSample,
        .value = rt_windowMaxCpuBurden,
    });

    rt_nextWindowEndSample += rt_samplesPerWindow;
    rt_windowMaxCpuBurden = newCpuBurden;
    rt_hasWindowCpuBurden = true;
  }
}

std::optional<NumericVisualizationData> PlayheadPositionVisualizationProvider::getTypedData() {
  return latestPlayheadPosition.drainLatest();
}

void PlayheadPositionVisualizationProvider::rt_updatePlayheadPosition(
    const Transport& transport, int64_t blockStartSample, int numSamples, double sampleRate) {
  if (sampleRate <= 0.0 || numSamples <= 0) {
    jassertfalse;
    return;
  }

  const auto samplesPerUpdate = samplesForDuration(sampleRate, playheadUpdateIntervalMs);
  if (rt_sampleRate != sampleRate || rt_samplesPerUpdate != samplesPerUpdate) {
    rt_sampleRate = sampleRate;
    rt_samplesPerUpdate = samplesPerUpdate;
    rt_nextSampleTimestamp = blockStartSample;
  }

  const auto blockEndSample = blockStartSample + static_cast<int64_t>(numSamples);

  if (!transport.rt_config->isPlaying) {
    if (transport.rt_playheadJumpOrPauseOccurred) {
      latestPlayheadPosition.rt_set(transport.rt_playhead, blockStartSample);
      rt_nextSampleTimestamp = blockStartSample + rt_samplesPerUpdate;
    } else {
      rt_nextSampleTimestamp = alignSampleTimestampToBlock(
          rt_nextSampleTimestamp, blockStartSample, rt_samplesPerUpdate);
    }

    while (rt_nextSampleTimestamp < blockEndSample) {
      latestPlayheadPosition.rt_set(transport.rt_playhead, rt_nextSampleTimestamp);
      rt_nextSampleTimestamp += rt_samplesPerUpdate;
    }

    return;
  }

  if (transport.rt_playheadJumpOrPauseOccurred) {
    latestPlayheadPosition.rt_set(transport.rt_playhead, blockStartSample);
    rt_nextSampleTimestamp = blockStartSample + rt_samplesPerUpdate;
  }

  rt_nextSampleTimestamp =
      alignSampleTimestampToBlock(rt_nextSampleTimestamp, blockStartSample, rt_samplesPerUpdate);

  while (rt_nextSampleTimestamp < blockEndSample) {
    const auto sampleOffset = static_cast<int>(rt_nextSampleTimestamp - blockStartSample);
    const auto playheadPosition = sampleOffset == 0
                                      ? transport.rt_playhead
                                      : transport.rt_getPlayheadAfterAdvance(sampleOffset);

    latestPlayheadPosition.rt_set(playheadPosition, rt_nextSampleTimestamp);
    rt_nextSampleTimestamp += rt_samplesPerUpdate;
  }
}

std::optional<IntegerVisualizationData> PlayheadSequenceIdVisualizationProvider::getTypedData() {
  return latestPlayheadSequenceId.drainLatest();
}

void PlayheadSequenceIdVisualizationProvider::rt_updatePlayheadSequenceId(
    int64_t newPlayheadSequenceId, int64_t sampleTimestamp) {
  // Refresh unchanged IDs too, so subscribers can recover current state and
  // valid timestamps after an audio session or visualization delivery reset.
  latestPlayheadSequenceId.rt_set(newPlayheadSequenceId, sampleTimestamp);
}

GlobalVisualizationSources::GlobalVisualizationSources() {
  cpuBurdenProvider =
      RegisteredVisualizationProvider<CpuVisualizationProvider>::registerDataProvider(
          "cpu", std::make_unique<CpuVisualizationProvider>());

  playheadPositionProvider =
      RegisteredVisualizationProvider<PlayheadPositionVisualizationProvider>::registerDataProvider(
          "playhead_position", std::make_unique<PlayheadPositionVisualizationProvider>());

  playheadSequenceIdProvider = RegisteredVisualizationProvider<
      PlayheadSequenceIdVisualizationProvider>::registerDataProvider("playhead_sequence_id",
      std::make_unique<PlayheadSequenceIdVisualizationProvider>());
}

} // namespace anthem
