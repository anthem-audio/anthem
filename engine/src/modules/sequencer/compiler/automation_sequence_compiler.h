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

#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <cstdint>
#include <optional>
#include <tuple>
#include <vector>

namespace anthem {

class AutomationSequenceCompiler {
  friend class AutomationSequenceCompilerTest;
public:
  using EntityId = int64_t;

  static void compilePattern(EntityId patternId);
  static void compilePattern(EntityId patternId, std::vector<EntityId>& trackIdsToRebuild);

  static void compileArrangement();
  static void compileArrangement(std::vector<EntityId>& trackIdsToRebuild);

  static void cleanUpTrack(EntityId trackId);
private:
  struct AutomationPointSnapshot {
    EntityId id = 0;
    double offset = 0.0;
    float value = 0.0f;
    double tension = 0.0;
    AutomationCurveType curve = AutomationCurveType::smooth;
  };

  struct AutomationClipSnapshot {
    EntityId id = 0;
    EntityId patternId = 0;
    EntityId trackId = 0;
    double offset = 0.0;
    std::optional<std::tuple<double, double>> sourceRange;
  };

  static AutomationSpanList getTrackAutomationForArrangement(EntityId trackId);

  static AutomationSpanList getPatternAutomationTrack(EntityId patternId);

  static void appendPatternAutomationSpans(EntityId patternId,
      double sourceStart,
      double sourceEnd,
      double arrangementStart,
      double holdEnd,
      AutomationSpanList& track);

  static std::vector<AutomationPointSnapshot> getAutomationPointsFromModel(EntityId patternId);

  static float evaluateAutomationAtSourceTick(
      const std::vector<AutomationPointSnapshot>& points, double tick);

  static double evaluateSmoothCurve(double normalizedX, double tension);
  static float evaluateSpanAtNormalizedPosition(
      const AutomationSequenceSpan& span, double normalizedPosition);
};

} // namespace anthem
