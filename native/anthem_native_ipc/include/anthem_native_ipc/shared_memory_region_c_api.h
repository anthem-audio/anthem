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

#pragma once

#include "anthem_native_ipc/native_ipc_c_api.h"

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AnthemSharedMemoryRegion AnthemSharedMemoryRegion;

/// The Dart-facing functions in this API, other than the finalizer-safe destroy
/// function, must be called only from the Flutter UI thread.
///
/// C++ exceptions never cross this ABI. Fallible functions return null or zero
/// and make a description available through anthem_native_ipc_get_last_error.

/// Creates and maps a shared memory region. Returns null on failure.
ANTHEM_NATIVE_IPC_API AnthemSharedMemoryRegion* anthem_shared_memory_region_create(
    uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Opens and maps an existing shared memory region. Returns null on failure.
ANTHEM_NATIVE_IPC_API AnthemSharedMemoryRegion* anthem_shared_memory_region_open(
    const char* identifier, uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Returns the process-local address of the mapped bytes.
ANTHEM_NATIVE_IPC_API uint8_t* anthem_shared_memory_region_get_data(
    AnthemSharedMemoryRegion* region) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API uint64_t anthem_shared_memory_region_get_size(
    const AnthemSharedMemoryRegion* region) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Returns an identifier owned by the region and valid until it is destroyed.
ANTHEM_NATIVE_IPC_API const char* anthem_shared_memory_region_get_identifier(
    const AnthemSharedMemoryRegion* region) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// See SharedMemoryRegion::removeIdentifier. Returns one on success and zero
/// on failure.
ANTHEM_NATIVE_IPC_API int32_t anthem_shared_memory_region_remove_identifier(
    AnthemSharedMemoryRegion* region) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API void anthem_shared_memory_region_destroy(
    AnthemSharedMemoryRegion* region) ANTHEM_NATIVE_IPC_NOEXCEPT;

#ifdef __cplusplus
}
#endif
