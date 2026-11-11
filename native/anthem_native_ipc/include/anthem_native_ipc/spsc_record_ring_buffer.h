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

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

namespace anthem::ipc {

/// Initializes a region for use by one SPSC record writer and one reader.
/// This must be called before either endpoint is constructed and while no
/// other process or thread is accessing the region.
/// The usable capacity is the largest power of two fitting after 128 bytes
/// of cursor storage. Any remaining bytes are unused.
void initializeSpscRecordRingBuffer(std::span<std::byte> bytes);

/// A non-blocking producer for variable-length records in shared memory.
///
/// A write publishes the entire record or returns false without publishing
/// any part of it. The producer never waits for the reader or advances the
/// reader's cursor.
class SpscRecordRingBufferWriter final {
public:
  explicit SpscRecordRingBufferWriter(std::span<std::byte> bytes);

  SpscRecordRingBufferWriter(const SpscRecordRingBufferWriter&) = delete;
  SpscRecordRingBufferWriter& operator=(const SpscRecordRingBufferWriter&) = delete;

  bool tryWrite(std::span<const std::byte> record) noexcept;

  std::size_t maximumRecordSize() const noexcept;
private:
  std::span<std::byte> bytes;
  std::uint32_t dataCapacity;
};

/// A single-consumer view of records published by
/// SpscRecordRingBufferWriter.
///
/// At most one record may be acquired at a time. Its bytes remain valid until
/// release() is called. The reader may internally consume wrap padding while
/// looking for the next record.
class SpscRecordRingBufferReader final {
public:
  explicit SpscRecordRingBufferReader(std::span<std::byte> bytes);

  SpscRecordRingBufferReader(const SpscRecordRingBufferReader&) = delete;
  SpscRecordRingBufferReader& operator=(const SpscRecordRingBufferReader&) = delete;

  std::optional<std::span<const std::byte>> tryAcquire();
  std::span<const std::byte> acquiredRecord() const;
  bool hasAcquiredRecord() const noexcept;
  std::size_t availableBytes() const noexcept;
  void release();

  std::size_t maximumRecordSize() const noexcept;
private:
  std::span<std::byte> bytes;
  std::uint32_t dataCapacity;
  std::uint32_t acquiredReadCursor = 0;
  std::uint32_t acquiredByteCount = 0;
  std::span<const std::byte> currentRecord;
};

} // namespace anthem::ipc
