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

#include "messages/messages.h"
#include "modules/processing_graph/processor/processor.h"

namespace anthem {
std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId,
    bool success,
    std::optional<std::string> error = std::nullopt,
    std::optional<std::shared_ptr<ProcessingGraphNodePortConfiguration>> ports = std::nullopt);
std::shared_ptr<ProcessingGraphNodeInitializationResult> makeNodeInitializationResult(
    int64_t nodeId, const ProcessorPrepareResult& result);
std::shared_ptr<std::vector<std::shared_ptr<ProcessingGraphParameterValue>>> makeParameterValueList(
    const std::vector<ProcessorParameterValue>& values);
} // namespace anthem
