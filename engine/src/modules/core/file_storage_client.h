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

#include "ipc_request_client.h"

namespace anthem {

struct FileStorageAccess {
  std::string token;
  std::string absolutePath;
};

template <typename Value> struct FileStorageResult {
  std::optional<Value> value;
  std::optional<std::string> error;
};

// Asynchronous access to the project's UI-owned file store.
//
// All calls and callbacks run on the message thread. File I/O belongs off the
// audio thread. Flush and close files before committing, aborting, or releasing
// read access. The store tracks read, write, and retention tokens in a file scope
// owned by this engine process. Successful commit, abort, and release operations
// consume their tokens. A timeout does not cancel UI work; remaining access is
// reclaimed after the engine has stopped.
class FileStorageClient {
public:
  using AccessCompletion = std::function<void(FileStorageResult<FileStorageAccess>)>;
  using RelativePathCompletion = std::function<void(FileStorageResult<std::string>)>;
  using TokenCompletion = std::function<void(FileStorageResult<std::string>)>;
  using Completion = std::function<void(std::optional<std::string> error)>;

  explicit FileStorageClient(IpcRequestClient& requests) : requests(requests) {}

  int64_t beginWrite(std::string category,
      AccessCompletion onComplete,
      std::optional<std::string> baseName = std::nullopt,
      std::optional<std::string> extension = std::nullopt);
  int64_t commitWrite(std::string token, RelativePathCompletion onComplete);
  int64_t abortWrite(std::string token, Completion onComplete);
  int64_t acquireRead(std::string relativePath, AccessCompletion onComplete);
  int64_t releaseRead(std::string token, Completion onComplete);
  int64_t deleteFile(std::string relativePath, Completion onComplete);
  int64_t retainFile(std::string relativePath, TokenCompletion onComplete);
  int64_t releaseRetention(std::string token, Completion onComplete);
private:
  IpcRequestClient& requests;
};

} // namespace anthem
