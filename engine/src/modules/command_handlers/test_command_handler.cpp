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

#include "modules/core/engine.h"
#include "modules/core/visualization/visualization_record.h"
#include "modules/processors/gain_parameter_mapping.h"

#include <cmath>
#include <vector>

// clang-analyzer loses track of the shared_ptr ownership when this response is
// wrapped into the generated TaggedUnion Response inside std::optional.
// NOLINTBEGIN(clang-analyzer-cplusplus.NewDeleteLeaks)
namespace anthem {

std::optional<Response> handleTestCommand(Request& request) {
  if (rfl::holds_alternative<TestFileStorageRequest>(request.variant())) {
    const auto& command = rfl::get<TestFileStorageRequest>(request.variant());
    const auto id = command.requestBase.get().id;
    auto reply = [id](TestFileStorageResponse response) {
      response.responseBase.get().id = id;
      auto json = rfl::json::write(Response{std::move(response)});
      Engine::getInstance().comms.send(json);
    };
    auto done = [reply](std::optional<std::string> error) {
      TestFileStorageResponse response{};
      response.error = std::move(error);
      reply(std::move(response));
    };
    auto access = [reply, command](FileStorageResult<FileStorageAccess> result) {
      TestFileStorageResponse response{};
      response.error = std::move(result.error);
      if (result.value) {
        response.token = result.value->token;
        response.absolutePath = result.value->absolutePath;
        const juce::File file(juce::String::fromUTF8(result.value->absolutePath.c_str()));
        if (command.operation == TestFileStorageOperation::beginWrite) {
          juce::FileOutputStream output(file);
          if (!output.openedOk() || !output.write(command.data.data(), command.data.size())) {
            response.error = "Test could not write the granted file.";
          }
          output.flush();
          if (output.getStatus().failed()) {
            response.error = output.getStatus().getErrorMessage().toStdString();
          }
        } else {
          juce::MemoryBlock bytes;
          if (file.loadFileAsData(bytes)) {
            response.data = std::string();
            if (bytes.getSize() != 0) {
              response.data =
                  std::string(static_cast<const char*>(bytes.getData()), bytes.getSize());
            }
          } else {
            response.error = "Test could not read the granted file.";
          }
        }
      }
      reply(std::move(response));
    };
    auto& storage = Engine::getInstance().fileStorage;
    switch (command.operation) {
      case TestFileStorageOperation::beginWrite:
        storage.beginWrite(
            command.category, std::move(access), command.baseName, command.extension);
        break;
      case TestFileStorageOperation::commitWrite:
        storage.commitWrite(command.token, [reply](FileStorageResult<std::string> result) {
          TestFileStorageResponse response{};
          response.relativePath = std::move(result.value);
          response.error = std::move(result.error);
          reply(std::move(response));
        });
        break;
      case TestFileStorageOperation::abortWrite:
        storage.abortWrite(command.token, std::move(done));
        break;
      case TestFileStorageOperation::acquireRead:
        storage.acquireRead(command.relativePath, std::move(access));
        break;
      case TestFileStorageOperation::releaseRead:
        storage.releaseRead(command.token, std::move(done));
        break;
      case TestFileStorageOperation::deleteFile:
        storage.deleteFile(command.relativePath, std::move(done));
        break;
      case TestFileStorageOperation::retainFile:
        storage.retainFile(command.relativePath, [reply](FileStorageResult<std::string> result) {
          TestFileStorageResponse response{};
          response.token = std::move(result.value);
          response.error = std::move(result.error);
          reply(std::move(response));
        });
        break;
      case TestFileStorageOperation::releaseRetention:
        storage.releaseRetention(command.token, std::move(done));
        break;
    }
    return std::nullopt;
  }
  if (rfl::holds_alternative<TestUiEchoRoundTripRequest>(request.variant())) {
    const auto& echoRequest = rfl::get<TestUiEchoRoundTripRequest>(request.variant());
    const auto id = echoRequest.requestBase.get().id;
    Engine::getInstance().uiRequests.request(
        TestUiEchoRequest{.value = echoRequest.value, .requestBase = RequestBase{}},
        [id](IpcRequestResult result) {
          TestUiEchoRoundTripResponse reply{
              .value = std::nullopt, .error = result.error, .responseBase = ResponseBase{.id = id}};
          if (result.response.has_value()) {
            if (rfl::holds_alternative<TestUiEchoResponse>(result.response->variant())) {
              reply.value = rfl::get<TestUiEchoResponse>(result.response->variant()).value;
            } else if (rfl::holds_alternative<RequestErrorResponse>(result.response->variant())) {
              reply.error = rfl::get<RequestErrorResponse>(result.response->variant()).message;
            } else {
              reply.error = "Unexpected UI echo response.";
            }
          }
          auto json = rfl::json::write(Response{reply});
          Engine::getInstance().comms.send(json);
        },
        std::chrono::milliseconds(echoRequest.timeoutMilliseconds));
    return std::nullopt;
  }
  if (rfl::holds_alternative<TestPublishVisualizationRecordRequest>(request.variant())) {
    const auto& testRequest = rfl::get<TestPublishVisualizationRecordRequest>(request.variant());
    const std::vector<VisualizationRecordItem> items{
        {"d-\xce\xa9", NumericVisualizationData{{10, 20}, {-0.0, 1.5}}},
        {"i", IntegerVisualizationData{{10, 20}, {-7, 9007199254740991LL}}},
    };
    static std::uint32_t sequence = 7;
    const auto bytes = encodeVisualizationRecord({sequence++, 9, 48000, 20}, items);
    auto* writer = Engine::getInstance().visualizationComms.getWriter();
    const bool success = writer != nullptr && bytes.has_value() && writer->tryWrite(*bytes);
    return TestPublishVisualizationRecordResponse{
        .success = success, .responseBase = ResponseBase{.id = testRequest.requestBase.get().id}};
  }
  if (!rfl::holds_alternative<TestSampleGainCurveRequest>(request.variant())) {
    return std::nullopt;
  }

  auto& requestAsTestSampleGainCurve = rfl::get<TestSampleGainCurveRequest>(request.variant());

  if (requestAsTestSampleGainCurve.parameterValues == nullptr) {
    return std::optional(
        TestSampleGainCurveResponse{.dbValues = std::make_shared<std::vector<double>>(),
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

} // namespace anthem
// NOLINTEND(clang-analyzer-cplusplus.NewDeleteLeaks)
