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

#include "anthem_native_ipc/spsc_record_ring_buffer_c_api.h"

#include "anthem_native_ipc/spsc_record_ring_buffer.h"
#include "c_api_error.h"

#include <cstddef>
#include <exception>
#include <limits>
#include <span>
#include <stdexcept>

struct AnthemSpscRecordRingBufferWriter {
  anthem::ipc::SpscRecordRingBufferWriter writer;
};

struct AnthemSpscRecordRingBufferReader {
  anthem::ipc::SpscRecordRingBufferReader reader;
};

namespace {

std::span<std::byte> checkedBytes(uint8_t* data, uint64_t size) {
  if (data == nullptr) {
    throw std::invalid_argument("Record ring buffer memory must not be null.");
  }
  if (size > std::numeric_limits<std::size_t>::max()) {
    throw std::invalid_argument("Record ring buffer memory is too large for this platform.");
  }

  return {reinterpret_cast<std::byte*>(data), static_cast<std::size_t>(size)};
}

template <typename Endpoint, typename Factory>
Endpoint* createEndpoint(Factory&& factory, const char* unknownError) noexcept {
  anthem::ipc::cApi::clearLastError();

  try {
    return new Endpoint{factory()};
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError(unknownError);
  }

  return nullptr;
}

} // namespace

int32_t anthem_spsc_record_ring_buffer_initialize(uint8_t* data, uint64_t size) noexcept {
  anthem::ipc::cApi::clearLastError();

  try {
    anthem::ipc::initializeSpscRecordRingBuffer(checkedBytes(data, size));
    return 1;
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError("Unknown error while initializing a record ring buffer.");
  }

  return 0;
}

AnthemSpscRecordRingBufferWriter* anthem_spsc_record_ring_buffer_writer_create(
    uint8_t* data, uint64_t size) noexcept {
  return createEndpoint<AnthemSpscRecordRingBufferWriter>(
      [data, size] { return anthem::ipc::SpscRecordRingBufferWriter(checkedBytes(data, size)); },
      "Unknown error while opening a record ring buffer writer.");
}

int32_t anthem_spsc_record_ring_buffer_writer_try_write(
    AnthemSpscRecordRingBufferWriter* writer, const uint8_t* record, uint64_t size) noexcept {
  anthem::ipc::cApi::clearLastError();

  if (writer == nullptr) {
    anthem::ipc::cApi::setLastError("Record ring buffer writer must not be null.");
    return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
  }
  if (record == nullptr && size != 0) {
    anthem::ipc::cApi::setLastError("Record bytes must not be null when the size is nonzero.");
    return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
  }
  if (size > writer->writer.maximumRecordSize()) {
    anthem::ipc::cApi::setLastError("Record is too large for the ring buffer.");
    return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
  }

  try {
    const auto recordBytes = std::span<const std::byte>(
        reinterpret_cast<const std::byte*>(record), static_cast<std::size_t>(size));
    return writer->writer.tryWrite(recordBytes) ? ANTHEM_SPSC_RECORD_RING_BUFFER_SUCCESS
                                                : ANTHEM_SPSC_RECORD_RING_BUFFER_UNAVAILABLE;
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError("Unknown error while writing a record ring buffer.");
  }

  return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
}

void anthem_spsc_record_ring_buffer_writer_destroy(
    AnthemSpscRecordRingBufferWriter* writer) noexcept {
  delete writer;
}

AnthemSpscRecordRingBufferReader* anthem_spsc_record_ring_buffer_reader_create(
    uint8_t* data, uint64_t size) noexcept {
  return createEndpoint<AnthemSpscRecordRingBufferReader>(
      [data, size] { return anthem::ipc::SpscRecordRingBufferReader(checkedBytes(data, size)); },
      "Unknown error while opening a record ring buffer reader.");
}

int32_t anthem_spsc_record_ring_buffer_reader_try_acquire(
    AnthemSpscRecordRingBufferReader* reader) noexcept {
  anthem::ipc::cApi::clearLastError();

  if (reader == nullptr) {
    anthem::ipc::cApi::setLastError("Record ring buffer reader must not be null.");
    return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
  }

  try {
    return reader->reader.tryAcquire().has_value() ? ANTHEM_SPSC_RECORD_RING_BUFFER_SUCCESS
                                                   : ANTHEM_SPSC_RECORD_RING_BUFFER_UNAVAILABLE;
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError("Unknown error while acquiring a record ring buffer record.");
  }

  return ANTHEM_SPSC_RECORD_RING_BUFFER_ERROR;
}

const uint8_t* anthem_spsc_record_ring_buffer_reader_get_data(
    const AnthemSpscRecordRingBufferReader* reader) noexcept {
  if (reader == nullptr || !reader->reader.hasAcquiredRecord()) {
    return nullptr;
  }

  return reinterpret_cast<const uint8_t*>(reader->reader.acquiredRecord().data());
}

uint64_t anthem_spsc_record_ring_buffer_reader_get_size(
    const AnthemSpscRecordRingBufferReader* reader) noexcept {
  if (reader == nullptr || !reader->reader.hasAcquiredRecord()) {
    return 0;
  }

  return static_cast<uint64_t>(reader->reader.acquiredRecord().size());
}

uint64_t anthem_spsc_record_ring_buffer_reader_get_available_bytes(
    const AnthemSpscRecordRingBufferReader* reader) noexcept {
  return reader == nullptr ? 0 : reader->reader.availableBytes();
}

int32_t anthem_spsc_record_ring_buffer_reader_release(
    AnthemSpscRecordRingBufferReader* reader) noexcept {
  anthem::ipc::cApi::clearLastError();

  if (reader == nullptr) {
    anthem::ipc::cApi::setLastError("Record ring buffer reader must not be null.");
    return 0;
  }

  try {
    reader->reader.release();
    return 1;
  } catch (const std::exception& error) {
    anthem::ipc::cApi::setLastError(error);
  } catch (...) {
    anthem::ipc::cApi::setLastError("Unknown error while releasing a record ring buffer record.");
  }

  return 0;
}

void anthem_spsc_record_ring_buffer_reader_destroy(
    AnthemSpscRecordRingBufferReader* reader) noexcept {
  delete reader;
}
