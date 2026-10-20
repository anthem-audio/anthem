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

#include "file_storage_client.h"

#include <utility>

namespace anthem {
namespace {

// Extracts the expected response or an error reported by the transport or UI.
template <typename ResponseType>
FileStorageResult<ResponseType> extractStorageResponse(IpcRequestResult result) {
  if (result.error)
    return {.value = std::nullopt, .error = std::move(result.error)};
  if (result.response) {
    const auto& response = result.response->variant();
    if (rfl::holds_alternative<ResponseType>(response)) {
      return {.value = rfl::get<ResponseType>(response), .error = std::nullopt};
    }
    if (rfl::holds_alternative<RequestErrorResponse>(response)) {
      return {.value = std::nullopt, .error = rfl::get<RequestErrorResponse>(response).message};
    }
  }
  return {.value = std::nullopt, .error = "Unexpected file storage response."};
}

} // namespace

int64_t FileStorageClient::beginWrite(std::string category,
    AccessCompletion onComplete,
    std::optional<std::string> baseName,
    std::optional<std::string> extension) {
  BeginFileWriteRequest request{.category = std::move(category),
      .baseName = std::move(baseName),
      .extension = std::move(extension),
      .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<BeginFileWriteResponse>(std::move(ipcResult));
        if (response.error) {
          onComplete({.value = std::nullopt, .error = std::move(response.error)});
          return;
        }
        onComplete({.value = FileStorageAccess{std::move(response.value->token),
                        std::move(response.value->absolutePath)},
            .error = std::nullopt});
      });
}

int64_t FileStorageClient::commitWrite(std::string token, RelativePathCompletion onComplete) {
  CommitFileWriteRequest request{.token = std::move(token), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<CommitFileWriteResponse>(std::move(ipcResult));
        if (response.error) {
          onComplete({.value = std::nullopt, .error = std::move(response.error)});
          return;
        }
        onComplete({.value = std::move(response.value->relativePath), .error = std::nullopt});
      });
}

int64_t FileStorageClient::abortWrite(std::string token, Completion onComplete) {
  AbortFileWriteRequest request{.token = std::move(token), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<FileStorageSuccessResponse>(std::move(ipcResult));
        onComplete(std::move(response.error));
      });
}

int64_t FileStorageClient::acquireRead(std::string relativePath, AccessCompletion onComplete) {
  AcquireFileReadRequest request{
      .relativePath = std::move(relativePath), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<AcquireFileReadResponse>(std::move(ipcResult));
        if (response.error) {
          onComplete({.value = std::nullopt, .error = std::move(response.error)});
          return;
        }
        onComplete({.value = FileStorageAccess{std::move(response.value->token),
                        std::move(response.value->absolutePath)},
            .error = std::nullopt});
      });
}

int64_t FileStorageClient::releaseRead(std::string token, Completion onComplete) {
  ReleaseFileReadRequest request{.token = std::move(token), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<FileStorageSuccessResponse>(std::move(ipcResult));
        onComplete(std::move(response.error));
      });
}

int64_t FileStorageClient::deleteFile(std::string relativePath, Completion onComplete) {
  DeleteStoredFileRequest request{
      .relativePath = std::move(relativePath), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<FileStorageSuccessResponse>(std::move(ipcResult));
        onComplete(std::move(response.error));
      });
}

int64_t FileStorageClient::retainFile(std::string relativePath, TokenCompletion onComplete) {
  RetainStoredFileRequest request{
      .relativePath = std::move(relativePath), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<RetainStoredFileResponse>(std::move(ipcResult));
        if (response.error) {
          onComplete({.value = std::nullopt, .error = std::move(response.error)});
          return;
        }
        onComplete({.value = std::move(response.value->token), .error = std::nullopt});
      });
}

int64_t FileStorageClient::releaseRetention(std::string token, Completion onComplete) {
  ReleaseStoredFileRetentionRequest request{
      .token = std::move(token), .requestBase = RequestBase{}};
  return requests.request(
      std::move(request), [onComplete = std::move(onComplete)](IpcRequestResult ipcResult) {
        auto response = extractStorageResponse<FileStorageSuccessResponse>(std::move(ipcResult));
        onComplete(std::move(response.error));
      });
}

} // namespace anthem
