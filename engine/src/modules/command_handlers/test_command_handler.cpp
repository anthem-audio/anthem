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

#include "test_command_handler.h"

#include "modules/processors/gain_parameter_mapping.h"

#include <cmath>
#include <vector>

// clang-analyzer loses track of the shared_ptr ownership when this response is
// wrapped into the generated TaggedUnion Response inside std::optional.
// NOLINTBEGIN(clang-analyzer-cplusplus.NewDeleteLeaks)
std::optional<Response> handleTestCommand(Request& request) {
  if (!rfl::holds_alternative<TestSampleGainCurveRequest>(request.variant())) {
    return std::nullopt;
  }

  auto& requestAsTestSampleGainCurve = rfl::get<TestSampleGainCurveRequest>(request.variant());

  if (requestAsTestSampleGainCurve.parameterValues == nullptr) {
    return std::optional(TestSampleGainCurveResponse{
        .dbValues = std::make_shared<std::vector<double>>(),
        .isNegativeInfinity = std::make_shared<std::vector<bool>>(),
        .responseBase = ResponseBase{.id = requestAsTestSampleGainCurve.requestBase.get().id}});
  }

  std::vector<double> dbValues;
  std::vector<bool> isNegativeInfinity;
  dbValues.reserve(requestAsTestSampleGainCurve.parameterValues->size());
  isNegativeInfinity.reserve(requestAsTestSampleGainCurve.parameterValues->size());

  for (const auto parameterValue : *requestAsTestSampleGainCurve.parameterValues) {
    const auto dbValue = gainParameterValueToDb(static_cast<float>(parameterValue));

    if (std::isinf(dbValue) && dbValue < 0.0f) {
      dbValues.push_back(0.0);
      isNegativeInfinity.push_back(true);
    } else {
      dbValues.push_back(dbValue);
      isNegativeInfinity.push_back(false);
    }
  }

  return std::optional(TestSampleGainCurveResponse{
      .dbValues = std::make_shared<std::vector<double>>(std::move(dbValues)),
      .isNegativeInfinity = std::make_shared<std::vector<bool>>(std::move(isNegativeInfinity)),
      .responseBase = ResponseBase{.id = requestAsTestSampleGainCurve.requestBase.get().id}});
}
// NOLINTEND(clang-analyzer-cplusplus.NewDeleteLeaks)
