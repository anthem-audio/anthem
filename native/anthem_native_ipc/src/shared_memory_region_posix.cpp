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

#if !defined(_WIN32) && !defined(__EMSCRIPTEN__)

#include "anthem_native_ipc/shared_memory_region.h"

#include <cerrno>
#include <chrono>
#include <cstdint>
#include <fcntl.h>
#include <iomanip>
#include <limits>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <system_error>
#include <unistd.h>
#include <utility>

namespace anthem::ipc {

namespace {

constexpr int maxCreateAttempts = 32;

std::string createIdentifierToken() {
  std::random_device randomDevice;
  auto token = (static_cast<std::uint64_t>(randomDevice()) << 32) ^ randomDevice();
  token ^= static_cast<std::uint64_t>(getpid()) << 16;
  token ^= static_cast<std::uint64_t>(
      std::chrono::high_resolution_clock::now().time_since_epoch().count());

  std::ostringstream stream;
  stream << std::hex << std::setfill('0') << std::setw(16) << token;
  return stream.str();
}

[[noreturn]] void throwPosixError(const char* operation, int error) {
  throw std::system_error(error, std::generic_category(), operation);
}

void closeDescriptor(int descriptor) {
  if (descriptor >= 0) {
    close(descriptor);
  }
}

} // namespace

class SharedMemoryRegion::Impl {
public:
  Impl(void* data, std::size_t size, std::string identifier, bool ownsIdentifier)
    : data(data), size(size), identifier(std::move(identifier)), ownsIdentifier(ownsIdentifier) {}

  ~Impl() {
    if (data != nullptr) {
      munmap(data, size);
    }

    if (ownsIdentifier) {
      shm_unlink(identifier.c_str());
    }
  }

  void* data;
  std::size_t size;
  std::string identifier;
  bool ownsIdentifier;
};

SharedMemoryRegion SharedMemoryRegion::create(std::size_t size) {
  if (size == 0) {
    throw std::invalid_argument("Shared memory region size must be greater than zero.");
  }

  if (size > static_cast<std::size_t>(std::numeric_limits<off_t>::max())) {
    throw std::invalid_argument("Shared memory region size is too large for this platform.");
  }

  for (int attempt = 0; attempt < maxCreateAttempts; ++attempt) {
    auto identifier = "/anthem_" + createIdentifierToken();
    auto descriptor = shm_open(identifier.c_str(), O_CREAT | O_EXCL | O_RDWR, S_IRUSR | S_IWUSR);

    if (descriptor < 0) {
      if (errno == EEXIST) {
        continue;
      }

      throwPosixError("shm_open", errno);
    }

    if (ftruncate(descriptor, static_cast<off_t>(size)) != 0) {
      const auto error = errno;
      closeDescriptor(descriptor);
      shm_unlink(identifier.c_str());
      throwPosixError("ftruncate", error);
    }

    auto data = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, descriptor, 0);
    if (data == MAP_FAILED) {
      const auto error = errno;
      closeDescriptor(descriptor);
      shm_unlink(identifier.c_str());
      throwPosixError("mmap", error);
    }

    closeDescriptor(descriptor);
    return SharedMemoryRegion(std::make_unique<Impl>(data, size, std::move(identifier), true));
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
  auto descriptor = shm_open(identifierString.c_str(), O_RDWR, S_IRUSR | S_IWUSR);
  if (descriptor < 0) {
    throwPosixError("shm_open", errno);
  }

  struct stat info{};
  if (fstat(descriptor, &info) != 0) {
    const auto error = errno;
    closeDescriptor(descriptor);
    throwPosixError("fstat", error);
  }

  if (info.st_size < 0 || static_cast<std::uint64_t>(info.st_size) != size) {
    closeDescriptor(descriptor);
    throw std::invalid_argument("Shared memory region size does not match the creator's size.");
  }

  auto data = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, descriptor, 0);
  if (data == MAP_FAILED) {
    const auto error = errno;
    closeDescriptor(descriptor);
    throwPosixError("mmap", error);
  }

  closeDescriptor(descriptor);
  return SharedMemoryRegion(std::make_unique<Impl>(data, size, std::move(identifierString), false));
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
  if (impl == nullptr || !impl->ownsIdentifier) {
    return;
  }

  if (shm_unlink(impl->identifier.c_str()) != 0 && errno != ENOENT) {
    throwPosixError("shm_unlink", errno);
  }

  impl->ownsIdentifier = false;
}

} // namespace anthem::ipc

#endif // !defined(_WIN32) && !defined(__EMSCRIPTEN__)
