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

#include "sequencer_command_handler.h"

#include "modules/core/engine.h"
#include "modules/sequencer/compiler/automation_sequence_compiler.h"
#include "modules/sequencer/compiler/sequence_compiler.h"

namespace anthem {

std::optional<Response> handleSequencerCommand(Request& request) {
  if (rfl::holds_alternative<CompilePatternRequest>(request.variant())) {
    auto& compilePatternRequest = rfl::get<CompilePatternRequest>(request.variant());

    if (compilePatternRequest.tracksToRebuild.has_value()) {
      auto invalidationRanges = std::vector<std::tuple<double, double>>();

      if (compilePatternRequest.invalidationRanges.has_value()) {
        invalidationRanges.reserve(compilePatternRequest.invalidationRanges.value()->size());

        for (const auto& range : *compilePatternRequest.invalidationRanges.value()) {
          invalidationRanges.push_back(std::make_tuple(range->start, range->end));
        }
      }

      // Compile only the specified tracks for the given pattern.
      SequenceCompiler::compilePattern(compilePatternRequest.patternId,
          *compilePatternRequest.tracksToRebuild.value(),
          invalidationRanges);

      AutomationSequenceCompiler::compilePattern(
          compilePatternRequest.patternId, *compilePatternRequest.tracksToRebuild.value());
    } else {
      // Compile the entire pattern
      SequenceCompiler::compilePattern(compilePatternRequest.patternId);
      AutomationSequenceCompiler::compilePattern(compilePatternRequest.patternId);
    }

    if (Engine::getInstance().transport->config.activeSequenceId ==
        compilePatternRequest.patternId) {
      auto& transport = *Engine::getInstance().transport;
      transport.updateLoopPoints();
      transport.updatePlayheadJumpEventForStart(true);
    }
  } else if (rfl::holds_alternative<CompileArrangementRequest>(request.variant())) {
    auto& compileArrangementRequest = rfl::get<CompileArrangementRequest>(request.variant());
    auto& engine = Engine::getInstance();
    auto arrangement = engine.project->sequence()->arrangement();
    if (arrangement == nullptr) {
      return std::nullopt;
    }

    if (compileArrangementRequest.tracksToRebuild.has_value()) {
      auto invalidationRanges = std::vector<std::tuple<double, double>>();

      if (compileArrangementRequest.invalidationRanges.has_value()) {
        invalidationRanges.reserve(compileArrangementRequest.invalidationRanges.value()->size());
        for (const auto& range : *compileArrangementRequest.invalidationRanges.value()) {
          invalidationRanges.push_back(std::make_tuple(range->start, range->end));
        }
      }

      // Compile only the specified tracks for the arrangement.
      SequenceCompiler::compileArrangement(
          *compileArrangementRequest.tracksToRebuild.value(), invalidationRanges);

      AutomationSequenceCompiler::compileArrangement(
          *compileArrangementRequest.tracksToRebuild.value());
    } else {
      // Compile the entire arrangement
      SequenceCompiler::compileArrangement();
      AutomationSequenceCompiler::compileArrangement();
    }

    if (engine.transport->config.activeSequenceId == arrangement->id()) {
      auto& transport = *engine.transport;
      transport.updateLoopPoints();
      transport.updatePlayheadJumpEventForStart(true);
    }
  } else if (rfl::holds_alternative<RemoveTrackRequest>(request.variant())) {
    auto& removeTrackRequest = rfl::get<RemoveTrackRequest>(request.variant());

    SequenceCompiler::cleanUpTrack(removeTrackRequest.trackId);
    AutomationSequenceCompiler::cleanUpTrack(removeTrackRequest.trackId);
  } else if (rfl::holds_alternative<PlayheadJumpRequest>(request.variant())) {
    auto& playheadJumpRequest = rfl::get<PlayheadJumpRequest>(request.variant());

    Engine::getInstance().transport->jumpTo(playheadJumpRequest.offset);
  } else if (rfl::holds_alternative<LoopPointsChangedRequest>(request.variant())) {
    auto& loopPointsChangedRequest = rfl::get<LoopPointsChangedRequest>(request.variant());

    auto& transport = *Engine::getInstance().transport;
    if (transport.config.activeSequenceId == loopPointsChangedRequest.sequenceId) {
      transport.updateLoopPoints();
    }
  }

  return std::nullopt;
}

} // namespace anthem
