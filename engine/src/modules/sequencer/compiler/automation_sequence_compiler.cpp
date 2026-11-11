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

#include "automation_sequence_compiler.h"

#include "generated/lib/model/model.h"
#include "modules/core/engine.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>

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

void AutomationSequenceCompiler::compilePattern(EntityId patternId) {
  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return;
  }

  AutomationSpanListCollection newSequence;
  auto* noTrackAutomation = new AutomationSpanList(getPatternAutomationTrack(patternId));

  newSequence.setTrack(sequencer_track_ids::noTrack, noTrackAutomation);

  auto& store = *engine.automationSequenceStore;
  store.addOrUpdateSequence(patternId, newSequence);
}

void AutomationSequenceCompiler::compilePattern(
    EntityId patternId, std::vector<EntityId>& trackIdsToRebuild) {
  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return;
  }

  bool shouldCompileNoTrackAutomation =
      std::find(trackIdsToRebuild.begin(), trackIdsToRebuild.end(), sequencer_track_ids::noTrack) !=
      trackIdsToRebuild.end();

  if (!shouldCompileNoTrackAutomation) {
    return;
  }

  auto& store = *engine.automationSequenceStore;
  store.addOrUpdateTrackInSequence(
      patternId, sequencer_track_ids::noTrack, getPatternAutomationTrack(patternId));
}

void AutomationSequenceCompiler::compileArrangement() {
  auto& engine = Engine::getInstance();

  auto arrangement = engine.project->sequence()->arrangement();
  if (arrangement == nullptr) {
    return;
  }
  auto arrangementId = arrangement->id();

  AutomationSpanListCollection newSequence;
  std::unordered_set<EntityId> trackIds;

  for (auto& [clipId, clip] : *arrangement->clips()) {
    trackIds.insert(clip->trackId());
  }

  for (auto trackId : trackIds) {
    auto* trackAutomation = new AutomationSpanList(getTrackAutomationForArrangement(trackId));
    newSequence.setTrack(trackId, trackAutomation);
  }

  auto& store = *engine.automationSequenceStore;
  store.addOrUpdateSequence(arrangementId, newSequence);
}

void AutomationSequenceCompiler::compileArrangement(std::vector<EntityId>& trackIdsToRebuild) {
  auto& engine = Engine::getInstance();
  auto arrangement = engine.project->sequence()->arrangement();
  if (arrangement == nullptr) {
    return;
  }
  auto arrangementId = arrangement->id();
  auto& store = *engine.automationSequenceStore;

  for (auto& trackId : trackIdsToRebuild) {
    store.addOrUpdateTrackInSequence(
        arrangementId, trackId, getTrackAutomationForArrangement(trackId));
  }
}

void AutomationSequenceCompiler::cleanUpTrack(EntityId trackId) {
  auto& store = *Engine::getInstance().automationSequenceStore;

  store.removeTrackFromAllSequences(trackId);
}

AutomationSpanList AutomationSequenceCompiler::getTrackAutomationForArrangement(EntityId trackId) {
  auto& engine = Engine::getInstance();

  AutomationSpanList track;

  auto arrangement = engine.project->sequence()->arrangement();
  if (arrangement == nullptr) {
    return track;
  }

  std::vector<AutomationClipSnapshot> clips;

  for (auto& [clipId, clip] : *arrangement->clips()) {
    if (clip->trackId() != trackId) {
      continue;
    }

    std::optional<std::tuple<double, double>> sourceRange = std::nullopt;
    auto& timeView = clip->timeView();
    if (timeView.has_value()) {
      auto timeViewModel = *timeView;
      if (timeViewModel != nullptr) {
        sourceRange = std::make_tuple(
            static_cast<double>(timeViewModel->start()), static_cast<double>(timeViewModel->end()));
      }
    }

    clips.push_back(AutomationClipSnapshot{
        .id = clip->id(),
        .patternId = clip->patternId(),
        .trackId = clip->trackId(),
        .offset = static_cast<double>(clip->offset()),
        .sourceRange = sourceRange,
    });
  }

  std::sort(clips.begin(),
      clips.end(),
      [](const AutomationClipSnapshot& left, const AutomationClipSnapshot& right) {
        if (left.offset != right.offset) {
          return left.offset < right.offset;
        }

        return left.id < right.id;
      });

  for (size_t clipIndex = 0; clipIndex < clips.size(); clipIndex++) {
    const auto& clip = clips.at(clipIndex);
    const double nextClipStart = clipIndex + 1 < clips.size()
                                     ? clips.at(clipIndex + 1).offset
                                     : std::numeric_limits<double>::infinity();
    const double holdEnd = nextClipStart;

    if (holdEnd <= clip.offset) {
      continue;
    }

    auto points = getAutomationPointsFromModel(clip.patternId);
    if (points.empty()) {
      continue;
    }

    const double sourceStart =
        clip.sourceRange.has_value() ? std::get<0>(clip.sourceRange.value()) : 0.0;
    const double sourceEnd =
        clip.sourceRange.has_value() ? std::get<1>(clip.sourceRange.value()) : points.back().offset;

    if (!track.hasInitialValue) {
      track.hasInitialValue = true;
      track.initialValue = evaluateAutomationAtSourceTick(points, sourceStart);
    }

    appendPatternAutomationSpans(
        clip.patternId, sourceStart, sourceEnd, clip.offset, holdEnd, track);
  }

  return track;
}

AutomationSpanList AutomationSequenceCompiler::getPatternAutomationTrack(EntityId patternId) {
  AutomationSpanList track;
  auto points = getAutomationPointsFromModel(patternId);

  if (points.empty()) {
    return track;
  }

  track.hasInitialValue = true;
  track.initialValue = points.front().value;

  appendPatternAutomationSpans(
      patternId, 0.0, points.back().offset, 0.0, std::numeric_limits<double>::infinity(), track);

  return track;
}

void AutomationSequenceCompiler::appendPatternAutomationSpans(EntityId patternId,
    double sourceStart,
    double sourceEnd,
    double arrangementStart,
    double holdEnd,
    AutomationSpanList& track) {
  auto points = getAutomationPointsFromModel(patternId);
  if (points.empty() || holdEnd <= arrangementStart) {
    return;
  }

  if (sourceEnd < sourceStart) {
    sourceEnd = sourceStart;
  }

  if (std::isfinite(holdEnd)) {
    sourceEnd = std::min(sourceEnd, sourceStart + std::max(0.0, holdEnd - arrangementStart));
  }

  float cursorValue = evaluateAutomationAtSourceTick(points, sourceStart);
  double cursorTick = arrangementStart;

  for (size_t pointIndex = 0; pointIndex + 1 < points.size(); pointIndex++) {
    const auto& firstPoint = points.at(pointIndex);
    const auto& secondPoint = points.at(pointIndex + 1);

    if (secondPoint.offset <= firstPoint.offset) {
      continue;
    }

    const double clippedSourceStart = std::max(sourceStart, firstPoint.offset);
    const double clippedSourceEnd = std::min(sourceEnd, secondPoint.offset);

    if (clippedSourceEnd <= clippedSourceStart) {
      continue;
    }

    const double spanStart = arrangementStart + clippedSourceStart - sourceStart;
    const double spanEnd = arrangementStart + clippedSourceEnd - sourceStart;

    if (spanStart > cursorTick) {
      track.spans.push_back(AutomationSequenceSpan{
          .startTick = cursorTick,
          .endTick = spanStart,
          .startValue = cursorValue,
          .endValue = cursorValue,
          .curve = AutomationCurveType::hold,
          .tension = 0.0,
          .sourceCurveStartNormalized = 0.0,
          .sourceCurveEndNormalized = 1.0,
      });
    }

    const double sourceCurveStartNormalized =
        (clippedSourceStart - firstPoint.offset) / (secondPoint.offset - firstPoint.offset);
    const double sourceCurveEndNormalized =
        (clippedSourceEnd - firstPoint.offset) / (secondPoint.offset - firstPoint.offset);

    AutomationSequenceSpan curveSpan{
        .startTick = spanStart,
        .endTick = spanEnd,
        .startValue = firstPoint.value,
        .endValue = secondPoint.value,
        .curve = secondPoint.curve,
        .tension = secondPoint.tension,
        .sourceCurveStartNormalized = clampNormalized(sourceCurveStartNormalized),
        .sourceCurveEndNormalized = clampNormalized(sourceCurveEndNormalized),
    };

    track.spans.push_back(curveSpan);

    cursorValue = evaluateAutomationAtSourceTick(points, clippedSourceEnd);
    cursorTick = spanEnd;
  }

  const double visibleSourceDuration = std::max(0.0, sourceEnd - sourceStart);
  const double visibleEndTick = arrangementStart + visibleSourceDuration;
  const float sourceEndValue = evaluateAutomationAtSourceTick(points, sourceEnd);

  if (visibleEndTick > cursorTick) {
    track.spans.push_back(AutomationSequenceSpan{
        .startTick = cursorTick,
        .endTick = visibleEndTick,
        .startValue = cursorValue,
        .endValue = sourceEndValue,
        .curve = AutomationCurveType::hold,
        .tension = 0.0,
        .sourceCurveStartNormalized = 0.0,
        .sourceCurveEndNormalized = 1.0,
    });
  }

  const double holdStart = std::max(cursorTick, visibleEndTick);
  if (holdEnd > holdStart) {
    track.spans.push_back(AutomationSequenceSpan{
        .startTick = holdStart,
        .endTick = holdEnd,
        .startValue = sourceEndValue,
        .endValue = sourceEndValue,
        .curve = AutomationCurveType::hold,
        .tension = 0.0,
        .sourceCurveStartNormalized = 0.0,
        .sourceCurveEndNormalized = 1.0,
    });
  }
}

std::vector<AutomationSequenceCompiler::AutomationPointSnapshot>
AutomationSequenceCompiler::getAutomationPointsFromModel(EntityId patternId) {
  auto& engine = Engine::getInstance();

  auto patternIter = engine.project->sequence()->patterns()->find(patternId);
  if (patternIter == engine.project->sequence()->patterns()->end()) {
    return {};
  }

  auto pattern = patternIter->second;
  if (pattern->automation() == nullptr || pattern->automation()->points() == nullptr) {
    return {};
  }

  std::vector<AutomationPointSnapshot> points;
  points.reserve(pattern->automation()->points()->size());

  for (auto& point : *pattern->automation()->points()) {
    points.push_back(AutomationPointSnapshot{
        .id = point->id(),
        .offset = static_cast<double>(point->offset()),
        .value = clampAutomationValue(static_cast<float>(point->value())),
        .tension = point->tension(),
        .curve = point->curve(),
    });
  }

  return points;
}

float AutomationSequenceCompiler::evaluateAutomationAtSourceTick(
    const std::vector<AutomationPointSnapshot>& points, double tick) {
  if (points.empty()) {
    return 0.0f;
  }

  bool hasExactPoint = false;
  float exactPointValue = 0.0f;
  for (const auto& point : points) {
    if (tick == point.offset) {
      hasExactPoint = true;
      exactPointValue = point.value;
    }
  }

  if (hasExactPoint) {
    return exactPointValue;
  }

  if (points.size() == 1 || tick < points.front().offset) {
    return points.front().value;
  }

  if (tick > points.back().offset) {
    return points.back().value;
  }

  for (size_t pointIndex = 0; pointIndex + 1 < points.size(); pointIndex++) {
    const auto& firstPoint = points.at(pointIndex);
    const auto& secondPoint = points.at(pointIndex + 1);

    if (secondPoint.offset <= firstPoint.offset) {
      continue;
    }

    if (tick < firstPoint.offset || tick > secondPoint.offset) {
      continue;
    }

    const double normalizedPosition =
        (tick - firstPoint.offset) / (secondPoint.offset - firstPoint.offset);

    AutomationSequenceSpan span{
        .startTick = firstPoint.offset,
        .endTick = secondPoint.offset,
        .startValue = firstPoint.value,
        .endValue = secondPoint.value,
        .curve = secondPoint.curve,
        .tension = secondPoint.tension,
        .sourceCurveStartNormalized = 0.0,
        .sourceCurveEndNormalized = 1.0,
    };

    return evaluateSpanAtNormalizedPosition(span, normalizedPosition);
  }

  return points.back().value;
}

double AutomationSequenceCompiler::evaluateSmoothCurve(double normalizedX, double tension) {
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

float AutomationSequenceCompiler::evaluateSpanAtNormalizedPosition(
    const AutomationSequenceSpan& span, double normalizedPosition) {
  double curveValue = 0.0;

  switch (span.curve) {
    case AutomationCurveType::smooth:
      curveValue = evaluateSmoothCurve(normalizedPosition, span.tension);
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

} // namespace anthem
