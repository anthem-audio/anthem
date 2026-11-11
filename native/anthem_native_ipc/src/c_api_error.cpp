/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#include "c_api_error.h"

#include "anthem_native_ipc/native_ipc_c_api.h"

#include <cstddef>
#include <memory>
#include <new>

namespace {

constexpr char noError[] = "";
constexpr char unknownError[] = "Unknown native IPC error.";
constexpr char errorStorageAllocationFailure[] = "Unable to retain the native IPC error message.";

std::unique_ptr<char[]> lastErrorStorage;
const char* lastErrorMessage = noError;

void setStaticLastError(const char* message) noexcept {
  lastErrorStorage.reset();
  lastErrorMessage = message;
}

} // namespace

namespace anthem::ipc::cApi {

void clearLastError() noexcept {
  lastErrorStorage.reset();
  lastErrorMessage = noError;
}

void setLastError(const char* message) noexcept {
  if (message == nullptr) {
    setStaticLastError(unknownError);
    return;
  }

  std::size_t length = 0;
  while (message[length] != '\0') {
    ++length;
  }

  auto* storage = new (std::nothrow) char[length + 1];
  if (storage == nullptr) {
    setStaticLastError(errorStorageAllocationFailure);
    return;
  }

  for (std::size_t index = 0; index <= length; ++index) {
    storage[index] = message[index];
  }

  lastErrorStorage.reset(storage);
  lastErrorMessage = storage;
}

void setLastError(const std::exception& error) noexcept {
  setLastError(error.what());
}

} // namespace anthem::ipc::cApi

const char* anthem_native_ipc_get_last_error() noexcept {
  return lastErrorMessage;
}
