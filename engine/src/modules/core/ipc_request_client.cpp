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

#include "ipc_request_client.h"

#include "comms.h"

#include <exception>
#include <memory>
#include <utility>
#include <vector>

namespace anthem {

IpcRequestClient::IpcRequestClient(Comms& comms, Now now) : comms(comms), now(std::move(now)) {}

IpcRequestClient::~IpcRequestClient() {
  close();
}

int64_t IpcRequestClient::request(
    Request request, Completion complete, std::chrono::milliseconds timeout) {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());
  if (closed) {
    complete({.response = std::nullopt, .error = "IPC request client is closed."});
    return -1;
  }
  if (timeout <= std::chrono::milliseconds::zero()) {
    complete({.response = std::nullopt, .error = "IPC request timeout must be positive."});
    return -1;
  }

  // Keep IDs exactly representable in JavaScript as well as native Dart.
  constexpr int64_t maxId = 9007199254740991LL;
  while (pending.contains(nextId)) {
    nextId = nextId == maxId ? 0 : nextId + 1;
  }
  const auto id = nextId;
  nextId = nextId == maxId ? 0 : nextId + 1;
  pending.emplace(id, Pending{std::move(complete), now() + timeout});
  if (!isTimerRunning()) {
    startTimer(25);
  }

  try {
    request.visit([id](auto& value) { value.requestBase.get().id = id; });
    auto json = rfl::json::write(request);
    comms.send(json);
  } catch (const std::exception& error) {
    auto entry = pending.extract(id);
    if (!entry.empty()) {
      if (pending.empty())
        stopTimer();
      entry.mapped().complete({.response = std::nullopt, .error = error.what()});
    }
  }
  return id;
}

bool IpcRequestClient::handleResponse(const Response& response) {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());
  const auto id = response.visit([](const auto& value) { return value.responseBase.get().id; });
  auto entry = pending.extract(id);
  if (entry.empty())
    return false;
  if (pending.empty())
    stopTimer();

  if (entry.mapped().deadline <= now()) {
    entry.mapped().complete({.response = std::nullopt, .error = "IPC request timed out."});
  } else {
    entry.mapped().complete({.response = response, .error = std::nullopt});
  }
  return true;
}

bool IpcRequestClient::cancel(int64_t id) {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());
  auto entry = pending.extract(id);
  if (entry.empty())
    return false;
  if (pending.empty())
    stopTimer();
  entry.mapped().complete({.response = std::nullopt, .error = "IPC request cancelled."});
  return true;
}

void IpcRequestClient::close() {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());
  if (closed)
    return;
  closed = true;
  stopTimer();
  auto cancelled = std::move(pending);
  pending.clear();
  for (auto& [_, entry] : cancelled) {
    entry.complete({.response = std::nullopt, .error = "IPC request client is closed."});
  }
}

void IpcRequestClient::expireTimedOutRequests() {
  jassert(juce::MessageManager::getInstance()->isThisTheMessageThread());
  const auto currentTime = now();
  std::vector<Completion> expired;
  for (auto entry = pending.begin(); entry != pending.end();) {
    if (entry->second.deadline <= currentTime) {
      expired.push_back(std::move(entry->second.complete));
      entry = pending.erase(entry);
    } else {
      ++entry;
    }
  }
  if (pending.empty())
    stopTimer();
  for (auto& complete : expired) {
    complete({.response = std::nullopt, .error = "IPC request timed out."});
  }
}

void IpcRequestClient::timerCallback() {
  expireTimedOutRequests();
}

} // namespace anthem
