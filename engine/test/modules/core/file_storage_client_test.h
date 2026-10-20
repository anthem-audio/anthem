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
#include "modules/core/file_storage_client.h"

namespace anthem {

class FileStorageClientTest : public juce::UnitTest {
public:
  FileStorageClientTest() : juce::UnitTest("FileStorageClientTest", "Anthem") {}

  void runTest() override {
    Comms comms;
    beginTest("Write access and committed relative paths are delivered through typed callbacks");
    {
      IpcRequestClient requests(comms);
      FileStorageClient storage(requests);
      std::optional<FileStorageAccess> access;
      const auto begin = storage.beginWrite("plugin states", [&](auto result) {
        expect(!result.error);
        access = result.value;
      });
      requests.handleResponse(BeginFileWriteResponse{.token = "write-token",
          .absolutePath = "/pending/state.tmp",
          .responseBase = ResponseBase{.id = begin}});
      expect(access.has_value());
      if (access) {
        expectEquals(access->token, std::string("write-token"));
        expectEquals(access->absolutePath, std::string("/pending/state.tmp"));
      }
      std::optional<std::string> relativePath;
      const auto commit = storage.commitWrite("write-token", [&](auto result) {
        expect(!result.error);
        relativePath = result.value;
      });
      requests.handleResponse(CommitFileWriteResponse{
          .relativePath = "plugin states/state.bin", .responseBase = ResponseBase{.id = commit}});
      expect(relativePath == std::optional<std::string>("plugin states/state.bin"));
    }

    beginTest("Retained references return tokens that can be released");
    {
      IpcRequestClient requests(comms);
      FileStorageClient storage(requests);
      std::optional<std::string> token;
      const auto retain = storage.retainFile("plugin states/state.bin", [&](auto result) {
        expect(!result.error);
        token = result.value;
      });
      requests.handleResponse(RetainStoredFileResponse{
          .token = "retention-token", .responseBase = ResponseBase{.id = retain}});
      expect(token == std::optional<std::string>("retention-token"));
      bool released = false;
      const auto release = storage.releaseRetention("retention-token", [&](auto error) {
        expect(!error);
        released = true;
      });
      requests.handleResponse(
          FileStorageSuccessResponse{.responseBase = ResponseBase{.id = release}});
      expect(released);
    }

    beginTest("UI errors and unexpected response types are reported to callers");
    {
      IpcRequestClient requests(comms);
      FileStorageClient storage(requests);
      std::optional<std::string> error;
      const auto read = storage.acquireRead("missing", [&](auto result) {
        expect(!result.value);
        error = result.error;
      });
      requests.handleResponse(RequestErrorResponse{.code = RequestErrorCode::failed,
          .message = "Unknown stored object",
          .responseBase = ResponseBase{.id = read}});
      expect(error == std::optional<std::string>("Unknown stored object"));
      const auto release = storage.releaseRead("read-token", [&](auto value) { error = value; });
      requests.handleResponse(CommitFileWriteResponse{
          .relativePath = "wrong reply", .responseBase = ResponseBase{.id = release}});
      expect(error == std::optional<std::string>("Unexpected file storage response."));
      const auto abort = storage.abortWrite("write-token", [&](auto value) { error = value; });
      requests.handleResponse(
          FileStorageSuccessResponse{.responseBase = ResponseBase{.id = abort}});
      expect(!error);
    }

    beginTest("Timeout, cancellation and shutdown keep transport failures visible");
    {
      IpcRequestClient::Clock::time_point now{};
      IpcRequestClient requests(comms, [&] { return now; });
      FileStorageClient storage(requests);
      std::optional<std::string> error;
      storage.beginWrite("plugin states", [&](auto result) { error = result.error; });
      now += std::chrono::seconds(6);
      requests.expireTimedOutRequests();
      expect(error == std::optional<std::string>("IPC request timed out."));
      const auto read = storage.acquireRead("state", [&](auto result) { error = result.error; });
      requests.cancel(read);
      expect(error == std::optional<std::string>("IPC request cancelled."));
      storage.deleteFile("state", [&](auto value) { error = value; });
      requests.close();
      expect(error == std::optional<std::string>("IPC request client is closed."));
    }
  }
};

static FileStorageClientTest fileStorageClientTest;

} // namespace anthem
