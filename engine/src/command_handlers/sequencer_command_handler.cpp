/*
  Copyright (C) 2025 Joshua Wade

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

#include "modules/core/anthem.h"
#include "modules/sequencer/compiler/sequence_compiler.h"

std::optional<Response> handleSequencerCommand(Request& request) {
  if (rfl::holds_alternative<CompileSequenceRequest>(request.variant())) {
		auto& compileSequenceRequest = rfl::get<CompileSequenceRequest>(request.variant());

    if (compileSequenceRequest.patternId.has_value()) {
      if (compileSequenceRequest.channelsToRebuild.has_value()) {
				// Compile only the specified channels for the given pattern
				AnthemSequenceCompiler::compilePattern(
					compileSequenceRequest.patternId.value(),
					*compileSequenceRequest.channelsToRebuild.value()
				);
			}
			else {
				// Compile the entire pattern
				AnthemSequenceCompiler::compilePattern(compileSequenceRequest.patternId.value());
      }
    }
    else if (compileSequenceRequest.arrangementId.has_value()) {
      if (compileSequenceRequest.channelsToRebuild.has_value()) {
        // Compile only the specified channels for the given arrangement
        AnthemSequenceCompiler::compileArrangement(
          compileSequenceRequest.arrangementId.value(),
          *compileSequenceRequest.channelsToRebuild.value()
        );
      }
      else {
        // Compile the entire arrangement
        AnthemSequenceCompiler::compileArrangement(compileSequenceRequest.arrangementId.value());
      }
    }
  }
  else if (rfl::holds_alternative<RemoveChannelRequest>(request.variant())) {
    auto& removeChannelRequest = rfl::get<RemoveChannelRequest>(request.variant());

		AnthemSequenceCompiler::cleanUpChannel(removeChannelRequest.channelId);
  }
  else if (rfl::holds_alternative<PlayheadJumpRequest>(request.variant())) {
    auto& playheadJumpRequest = rfl::get<PlayheadJumpRequest>(request.variant());

    Anthem::getInstance().transport->jumpTo(playheadJumpRequest.offset);
  }
  else if (rfl::holds_alternative<LoopPointsChangedRequest>(request.variant())) {
    auto& loopPointsChangedRequest = rfl::get<LoopPointsChangedRequest>(request.variant());

    auto& transport = *Anthem::getInstance().transport;
    if (transport.config.activeSequenceId == loopPointsChangedRequest.sequenceId) {
      transport.updateLoopPoints();
    }
  }

  return std::nullopt;
}
