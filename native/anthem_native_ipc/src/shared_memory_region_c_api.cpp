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

#include "anthem_native_ipc/shared_memory_region_c_api.h"

#include "anthem_native_ipc/shared_memory_region.h"
#include "c_api_error.h"

#include <cstddef>
#include <exception>
#include <limits>
#include <stdexcept>

struct AnthemSharedMemoryRegion {
  anthem::ipc::SharedMemoryRegion region;
};

namespace {

std::size_t checkedSize(uint64_t size) {
  if (size == 0) {
    throw std::invalid_argument("Shared memory region size must be greater than zero.");
  }

  if (size > std::numeric_limits<std::size_t>::max()) {
    throw std::invalid_argument("Shared memory region size is too large for this platform.");
  }

  return static_cast<std::size_t>(size);
}

template <typename Factory> AnthemSharedMemoryRegion* createRegion(Factory&& factory) noexcept {
  anthem::ipc::cApi::clearLastError();

  try {
    return new AnthemSharedMemoryRegion{factory()};
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError("Unknown error while creating a shared memory mapping.");
  }

  return nullptr;
}

} // namespace

AnthemSharedMemoryRegion* anthem_shared_memory_region_create(uint64_t size) noexcept {
  return createRegion(
      [size] { return anthem::ipc::SharedMemoryRegion::create(checkedSize(size)); });
}

AnthemSharedMemoryRegion* anthem_shared_memory_region_open(
    const char* identifier, uint64_t size) noexcept {
  return createRegion([identifier, size] {
    if (identifier == nullptr || identifier[0] == '\0') {
      throw std::invalid_argument("Shared memory region identifier must not be empty.");
    }

    return anthem::ipc::SharedMemoryRegion::open(identifier, checkedSize(size));
  });
}

uint8_t* anthem_shared_memory_region_get_data(AnthemSharedMemoryRegion* region) noexcept {
  if (region == nullptr) {
    return nullptr;
  }

  return reinterpret_cast<uint8_t*>(region->region.bytes().data());
}

uint64_t anthem_shared_memory_region_get_size(const AnthemSharedMemoryRegion* region) noexcept {
  if (region == nullptr) {
    return 0;
  }

  return static_cast<uint64_t>(region->region.bytes().size());
}

const char* anthem_shared_memory_region_get_identifier(
    const AnthemSharedMemoryRegion* region) noexcept {
  if (region == nullptr) {
    return nullptr;
  }

  return region->region.identifier().data();
}

int32_t anthem_shared_memory_region_remove_identifier(AnthemSharedMemoryRegion* region) noexcept {
  anthem::ipc::cApi::clearLastError();

  if (region == nullptr) {
    anthem::ipc::cApi::setLastError("Shared memory region must not be null.");
    return 0;
  }

  try {
    region->region.removeIdentifier();
    return 1;
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError(
        "Unknown error while removing a shared memory region identifier.");
  }

  return 0;
}

void anthem_shared_memory_region_destroy(AnthemSharedMemoryRegion* region) noexcept {
  delete region;
}
