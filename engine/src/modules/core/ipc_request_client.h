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

#include <chrono>
#include <functional>
#include <juce_events/juce_events.h>
#include <optional>
#include <string>
#include <unordered_map>

namespace anthem {

class Comms;

struct IpcRequestResult {
  // The received response, which may report an operation failure.
  std::optional<Response> response;
  // Failures such as timeouts or client shutdown complete without a response.
  std::optional<std::string> error;
};

// Sends asynchronous IPC requests and matches responses to pending callbacks.
//
// Requests are serialized as JSON and sent to the UI through Comms.
//
// All methods and completion callbacks run on the JUCE message thread. Callers
// must not use this class on the audio thread or block the message thread while
// waiting for a response.
class IpcRequestClient : private juce::Timer {
public:
  using Clock = std::chrono::steady_clock;
  using Completion = std::function<void(IpcRequestResult)>;
  using Now = std::function<Clock::time_point()>;

  // Comms must outlive this client.
  explicit IpcRequestClient(Comms& comms, Now now = Clock::now);
  ~IpcRequestClient() override;

  // Assigns the request's ID and sends it without blocking. IDs are scoped to
  // this client, separately from requests initiated by the peer.
  int64_t request(Request request,
      Completion complete,
      std::chrono::milliseconds timeout = std::chrono::seconds(5));
  // Unknown IDs (including duplicate or late replies) are ignored.
  bool handleResponse(const Response& response);
  bool cancel(int64_t id);
  void close();

  // Also called by the timer. The injectable clock allows deterministic tests.
  void expireTimedOutRequests();
private:
  struct Pending {
    Completion complete;
    Clock::time_point deadline;
  };

  Comms& comms;
  Now now;
  std::unordered_map<int64_t, Pending> pending;
  int64_t nextId = 0;
  bool closed = false;

  void timerCallback() override;

  JUCE_DECLARE_NON_COPYABLE(IpcRequestClient)
};

} // namespace anthem
