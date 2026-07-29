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

#ifdef _WIN32

#include "anthem_native_ipc/shared_memory_region.h"

#include <Windows.h>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <system_error>
#include <utility>

namespace anthem::ipc {

namespace {

constexpr int maxCreateAttempts = 32;

std::string createIdentifierToken() {
  std::random_device randomDevice;
  auto token = (static_cast<std::uint64_t>(randomDevice()) << 32) ^ randomDevice();
  token ^= static_cast<std::uint64_t>(GetCurrentProcessId()) << 16;
  token ^= static_cast<std::uint64_t>(
      std::chrono::high_resolution_clock::now().time_since_epoch().count());

  std::ostringstream stream;
  stream << std::hex << std::setfill('0') << std::setw(16) << token;
  return stream.str();
}

std::wstring widenIdentifier(std::string_view identifier) {
  return {identifier.begin(), identifier.end()};
}

[[noreturn]] void throwWindowsError(const char* operation, DWORD error) {
  throw std::system_error(static_cast<int>(error), std::system_category(), operation);
}

} // namespace

class SharedMemoryRegion::Impl {
public:
  Impl(HANDLE mappingHandle, void* data, std::size_t size, std::string identifier)
    : mappingHandle(mappingHandle), data(data), size(size), identifier(std::move(identifier)) {}

  ~Impl() {
    if (data != nullptr) {
      UnmapViewOfFile(data);
    }

    if (mappingHandle != nullptr) {
      CloseHandle(mappingHandle);
    }
  }

  HANDLE mappingHandle;
  void* data;
  std::size_t size;
  std::string identifier;
};

SharedMemoryRegion SharedMemoryRegion::create(std::size_t size) {
  if (size == 0) {
    throw std::invalid_argument("Shared memory region size must be greater than zero.");
  }

  for (int attempt = 0; attempt < maxCreateAttempts; ++attempt) {
    auto identifier = "Local\\Anthem_" + createIdentifierToken();
    auto wideIdentifier = widenIdentifier(identifier);
    const auto size64 = static_cast<std::uint64_t>(size);

    auto mappingHandle = CreateFileMappingW(INVALID_HANDLE_VALUE,
        nullptr,
        PAGE_READWRITE,
        static_cast<DWORD>(size64 >> 32),
        static_cast<DWORD>(size64),
        wideIdentifier.c_str());

    if (mappingHandle == nullptr) {
      throwWindowsError("CreateFileMappingW", GetLastError());
    }

    if (GetLastError() == ERROR_ALREADY_EXISTS) {
      CloseHandle(mappingHandle);
      continue;
    }

    auto data = MapViewOfFile(mappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, size);
    if (data == nullptr) {
      const auto error = GetLastError();
      CloseHandle(mappingHandle);
      throwWindowsError("MapViewOfFile", error);
    }

    return SharedMemoryRegion(
        std::make_unique<Impl>(mappingHandle, data, size, std::move(identifier)));
  }

  throw std::runtime_error("Unable to create a unique shared memory region identifier.");
}

SharedMemoryRegion SharedMemoryRegion::open(std::string_view identifier, std::size_t size) {
  if (identifier.empty()) {
    throw std::invalid_argument("Shared memory region identifier must not be empty.");
  }

  if (size == 0) {
    throw std::invalid_argument("Shared memory region size must be greater than zero.");
  }

  auto identifierString = std::string(identifier);
  auto wideIdentifier = widenIdentifier(identifierString);
  auto mappingHandle = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, wideIdentifier.c_str());

  if (mappingHandle == nullptr) {
    throwWindowsError("OpenFileMappingW", GetLastError());
  }

  auto data = MapViewOfFile(mappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, size);
  if (data == nullptr) {
    const auto error = GetLastError();
    CloseHandle(mappingHandle);
    throwWindowsError("MapViewOfFile", error);
  }

  return SharedMemoryRegion(
      std::make_unique<Impl>(mappingHandle, data, size, std::move(identifierString)));
}

SharedMemoryRegion::SharedMemoryRegion(std::unique_ptr<Impl> impl) : impl(std::move(impl)) {}

SharedMemoryRegion::SharedMemoryRegion(SharedMemoryRegion&&) noexcept = default;

SharedMemoryRegion& SharedMemoryRegion::operator=(SharedMemoryRegion&&) noexcept = default;

SharedMemoryRegion::~SharedMemoryRegion() = default;

std::span<std::byte> SharedMemoryRegion::bytes() noexcept {
  if (impl == nullptr) {
    return {};
  }

  return {static_cast<std::byte*>(impl->data), impl->size};
}

std::span<const std::byte> SharedMemoryRegion::bytes() const noexcept {
  if (impl == nullptr) {
    return {};
  }

  return {static_cast<const std::byte*>(impl->data), impl->size};
}

std::string_view SharedMemoryRegion::identifier() const noexcept {
  return impl == nullptr ? std::string_view{} : std::string_view(impl->identifier);
}

void SharedMemoryRegion::removeIdentifier() {
  // Windows removes the name after the final mapping handle closes.
}

} // namespace anthem::ipc

#endif // _WIN32
