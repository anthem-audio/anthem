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

typedef struct AnthemSpscRecordRingBufferWriter AnthemSpscRecordRingBufferWriter;
typedef struct AnthemSpscRecordRingBufferReader AnthemSpscRecordRingBufferReader;

/// Result values returned by non-blocking record operations.
typedef enum AnthemSpscRecordRingBufferResult {
  ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR = -1,
  ANTHEM_SPSC_RECORD_RING_BUFFER_UNAVAILABLE = 0,
  ANTHEM_SPSC_RECORD_RING_BUFFER_SUCCESS = 1,
} AnthemSpscRecordRingBufferResult;

/// Initializes the supplied memory while it is exclusively owned by the
/// caller. Returns one on success and zero on failure.
ANTHEM_NATIVE_IPC_API int32_t anthem_spsc_record_ring_buffer_initialize(
    uint8_t* data, uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API AnthemSpscRecordRingBufferWriter*
anthem_spsc_record_ring_buffer_writer_create(
    uint8_t* data, uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Returns SUCCESS when the whole record was written, UNAVAILABLE when there
/// is insufficient free space, and ERROR for an invalid call or ring.
ANTHEM_NATIVE_IPC_API int32_t anthem_spsc_record_ring_buffer_writer_try_write(
    AnthemSpscRecordRingBufferWriter* writer,
    const uint8_t* record,
    uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API void anthem_spsc_record_ring_buffer_writer_destroy(
    AnthemSpscRecordRingBufferWriter* writer) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API AnthemSpscRecordRingBufferReader*
anthem_spsc_record_ring_buffer_reader_create(
    uint8_t* data, uint64_t size) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Returns SUCCESS when a record was acquired, UNAVAILABLE when the ring is
/// empty, and ERROR for an invalid call or ring.
ANTHEM_NATIVE_IPC_API int32_t anthem_spsc_record_ring_buffer_reader_try_acquire(
    AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// These accessors are valid only while the reader has an acquired record.
ANTHEM_NATIVE_IPC_API const uint8_t* anthem_spsc_record_ring_buffer_reader_get_data(
    const AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;
ANTHEM_NATIVE_IPC_API uint64_t anthem_spsc_record_ring_buffer_reader_get_size(
    const AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;

/// Releases the current record and advances the shared read cursor. Returns
/// one on success and zero on failure.
ANTHEM_NATIVE_IPC_API int32_t anthem_spsc_record_ring_buffer_reader_release(
    AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API uint64_t anthem_spsc_record_ring_buffer_reader_get_available_bytes(
    const AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;

ANTHEM_NATIVE_IPC_API void anthem_spsc_record_ring_buffer_reader_destroy(
    AnthemSpscRecordRingBufferReader* reader) ANTHEM_NATIVE_IPC_NOEXCEPT;

#ifdef __cplusplus
}
#endif
