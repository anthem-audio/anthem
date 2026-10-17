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

#include "modules/core/comms.h"
#include "modules/core/ipc_request_client.h"

#include <juce_core/juce_core.h>
#include <vector>

namespace anthem {

class IpcRequestClientTest : public juce::UnitTest {
public:
  IpcRequestClientTest() : juce::UnitTest("IpcRequestClientTest", "Anthem") {}

  static Request echoRequest(const std::string& value = "hello") {
    return TestUiEchoRequest{.value = value, .requestBase = RequestBase{}};
  }

  static Response echoResponse(int64_t id, const std::string& value = "reply") {
    return TestUiEchoResponse{.value = value, .responseBase = ResponseBase{.id = id}};
  }

  void runTest() override {
    // Leave Comms disconnected so requests remain queued. These tests supply
    // responses directly; engine integration tests cover delivery over IPC.
    Comms comms;

    beginTest("Replies are correlated independently and may arrive out of order");
    {
      std::vector<std::string> completed;
      IpcRequestClient client(comms);
      const auto first = client.request(echoRequest("first"), [&](IpcRequestResult result) {
        expect(result.response.has_value());
        if (result.response) {
          completed.push_back(rfl::get<TestUiEchoResponse>(result.response->variant()).value);
        }
      });
      const auto second = client.request(echoRequest("second"), [&](IpcRequestResult result) {
        expect(result.response.has_value());
        if (result.response) {
          completed.push_back(rfl::get<TestUiEchoResponse>(result.response->variant()).value);
        }
      });
      expectEquals(first, int64_t{0});
      expectEquals(second, int64_t{1});
      expect(client.handleResponse(echoResponse(second, "second")));
      expect(client.handleResponse(echoResponse(first, "first")));
      expect(completed == std::vector<std::string>{"second", "first"});
      expect(!client.handleResponse(echoResponse(first)));
      expect(!client.handleResponse(echoResponse(999)));
      expectEquals(static_cast<int>(completed.size()), 2);
    }

    beginTest("Timeout completes once and late replies are ignored");
    {
      IpcRequestClient::Clock::time_point now{};
      std::vector<IpcRequestResult> completed;
      IpcRequestClient client(comms, [&] { return now; });
      const auto id = client.request(
          echoRequest(),
          [&](auto result) { completed.push_back(result); },
          std::chrono::milliseconds(100));
      now += std::chrono::milliseconds(99);
      client.expireTimedOutRequests();
      expect(completed.empty());
      now += std::chrono::milliseconds(1);
      client.expireTimedOutRequests();
      expectEquals(static_cast<int>(completed.size()), 1);
      expect(completed[0].error == std::optional<std::string>("IPC request timed out."));
      expect(!client.handleResponse(echoResponse(id)));
      client.close();
      expectEquals(static_cast<int>(completed.size()), 1);
    }

    beginTest("An expired reply is rejected even before the timer next runs");
    {
      IpcRequestClient::Clock::time_point now{};
      std::optional<std::string> error;
      IpcRequestClient client(comms, [&] { return now; });
      const auto id = client.request(
          echoRequest(),
          [&](auto result) { error = result.error; },
          std::chrono::milliseconds(100));
      now += std::chrono::milliseconds(101);
      expect(client.handleResponse(echoResponse(id)));
      expect(error == std::optional<std::string>("IPC request timed out."));
    }

    beginTest("Cancellation and shutdown complete pending requests once");
    {
      std::vector<IpcRequestResult> completed;
      IpcRequestClient client(comms);
      const auto first =
          client.request(echoRequest(), [&](auto result) { completed.push_back(result); });
      const auto second =
          client.request(echoRequest(), [&](auto result) { completed.push_back(result); });
      expect(client.cancel(first));
      expect(!client.cancel(first));
      expect(completed[0].error == std::optional<std::string>("IPC request cancelled."));
      client.close();
      client.close();
      expect(!client.handleResponse(echoResponse(second)));
      expectEquals(static_cast<int>(completed.size()), 2);
      expect(completed[1].error == std::optional<std::string>("IPC request client is closed."));
      expectEquals(client.request(echoRequest(), [&](auto result) { completed.push_back(result); }),
          int64_t{-1});
      expectEquals(static_cast<int>(completed.size()), 3);
    }

    beginTest("Operation failures remain typed replies");
    {
      std::optional<Response> response;
      IpcRequestClient client(comms);
      const auto id = client.request(echoRequest(), [&](auto result) {
        expect(!result.error.has_value());
        response = result.response;
      });
      expect(client.handleResponse(RequestErrorResponse{.code = RequestErrorCode::unsupported,
          .message = "Not supported",
          .responseBase = ResponseBase{.id = id}}));
      expect(response.has_value());
      if (response) {
        expect(rfl::get<RequestErrorResponse>(response->variant()).code ==
               RequestErrorCode::unsupported);
      }
    }

    beginTest("Completion can initiate another request");
    {
      int completions = 0;
      IpcRequestClient client(comms);
      int64_t second = -1;
      const auto first = client.request(echoRequest(), [&](auto) {
        ++completions;
        second = client.request(echoRequest(), [&](auto) { ++completions; });
      });
      expect(client.handleResponse(echoResponse(first)));
      expect(client.handleResponse(echoResponse(second)));
      expectEquals(completions, 2);
    }
  }
};

static IpcRequestClientTest ipcRequestClientTest;

} // namespace anthem
