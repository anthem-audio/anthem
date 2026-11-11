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

#include "anthem_native_ipc/spsc_record_ring_buffer.h"

#include <algorithm>
#include <atomic>
#include <bit>
#include <cstring>
#include <limits>
#include <stdexcept>

namespace anthem::ipc {

namespace {

constexpr std::size_t cursorAlignment = alignof(std::uint32_t);
constexpr std::size_t readCursorOffset = 0;
constexpr std::size_t writeCursorOffset = 64;
constexpr std::size_t dataOffset = 128;
constexpr std::size_t recordHeaderSize = sizeof(std::uint32_t);
constexpr std::uint32_t wrapMarker = std::numeric_limits<std::uint32_t>::max();
constexpr std::size_t minimumDataCapacity = 16;
constexpr std::uint32_t maximumDataCapacity = std::numeric_limits<std::uint32_t>::max() / 2;

static_assert(std::atomic_ref<std::uint32_t>::is_always_lock_free,
    "The shared record ring requires lock-free 32-bit atomics.");

std::uint32_t validateAndGetDataCapacity(std::span<std::byte> bytes) {
  if (bytes.data() == nullptr) {
    throw std::invalid_argument("Record ring buffer memory must not be null.");
  }

  if (reinterpret_cast<std::uintptr_t>(bytes.data()) % cursorAlignment != 0) {
    throw std::invalid_argument("Record ring buffer memory is not suitably aligned.");
  }

  if (bytes.size() < dataOffset + minimumDataCapacity) {
    throw std::invalid_argument("Record ring buffer memory is too small.");
  }

  const auto dataCapacity = bytes.size() - dataOffset;
  if (dataCapacity > maximumDataCapacity) {
    throw std::invalid_argument("Record ring buffer memory is too large.");
  }

  // A power-of-two capacity divides the uint32 cursor range. Otherwise a
  // cursor rollover changes its physical offset and corrupts queued records.
  return std::bit_floor(static_cast<std::uint32_t>(dataCapacity));
}

std::uint32_t& uint32At(std::span<std::byte> bytes, std::size_t offset) noexcept {
  return *reinterpret_cast<std::uint32_t*>(bytes.data() + offset);
}

std::atomic_ref<std::uint32_t> readCursor(std::span<std::byte> bytes) noexcept {
  return std::atomic_ref<std::uint32_t>(uint32At(bytes, readCursorOffset));
}

std::atomic_ref<std::uint32_t> writeCursor(std::span<std::byte> bytes) noexcept {
  return std::atomic_ref<std::uint32_t>(uint32At(bytes, writeCursorOffset));
}

std::byte* data(std::span<std::byte> bytes) noexcept {
  return bytes.data() + dataOffset;
}

std::size_t maximumRecordSize(std::uint32_t dataCapacity) noexcept {
  return (dataCapacity / 2) - recordHeaderSize;
}

void writeRecordLength(std::byte* destination, std::uint32_t length) noexcept {
  std::memcpy(destination, &length, sizeof(length));
}

std::uint32_t readRecordLength(const std::byte* source) noexcept {
  std::uint32_t length = 0;
  std::memcpy(&length, source, sizeof(length));
  return length;
}

} // namespace

void initializeSpscRecordRingBuffer(std::span<std::byte> bytes) {
  validateAndGetDataCapacity(bytes);

  std::memset(bytes.data(), 0, dataOffset);
  readCursor(bytes).store(0, std::memory_order_relaxed);
  writeCursor(bytes).store(0, std::memory_order_relaxed);
}

SpscRecordRingBufferWriter::SpscRecordRingBufferWriter(std::span<std::byte> bytes)
  : bytes(bytes), dataCapacity(validateAndGetDataCapacity(bytes)) {}

bool SpscRecordRingBufferWriter::tryWrite(std::span<const std::byte> record) noexcept {
  if (record.size() > maximumRecordSize()) {
    return false;
  }

  const auto currentReadCursor = readCursor(bytes).load(std::memory_order_acquire);
  const auto currentWriteCursor = writeCursor(bytes).load(std::memory_order_relaxed);
  const auto usedByteCount = currentWriteCursor - currentReadCursor;

  if (usedByteCount > dataCapacity) {
    return false;
  }

  const auto recordByteCount = static_cast<std::uint32_t>(recordHeaderSize + record.size());
  const auto writeOffset = currentWriteCursor % dataCapacity;
  const auto contiguousByteCount = dataCapacity - writeOffset;
  const auto paddingByteCount = recordByteCount > contiguousByteCount ? contiguousByteCount : 0;
  const auto requiredByteCount = paddingByteCount + recordByteCount;
  const auto availableByteCount = dataCapacity - usedByteCount;

  if (requiredByteCount > availableByteCount) {
    return false;
  }

  auto* ringData = data(bytes);
  auto recordOffset = writeOffset;

  if (paddingByteCount > 0) {
    if (paddingByteCount >= recordHeaderSize) {
      writeRecordLength(ringData + writeOffset, wrapMarker);
    }
    recordOffset = 0;
  }

  writeRecordLength(ringData + recordOffset, static_cast<std::uint32_t>(record.size()));
  if (!record.empty()) {
    std::memcpy(ringData + recordOffset + recordHeaderSize, record.data(), record.size());
  }

  writeCursor(bytes).store(currentWriteCursor + requiredByteCount, std::memory_order_release);
  return true;
}

std::size_t SpscRecordRingBufferWriter::maximumRecordSize() const noexcept {
  return ::anthem::ipc::maximumRecordSize(dataCapacity);
}

SpscRecordRingBufferReader::SpscRecordRingBufferReader(std::span<std::byte> bytes)
  : bytes(bytes), dataCapacity(validateAndGetDataCapacity(bytes)) {}

std::optional<std::span<const std::byte>> SpscRecordRingBufferReader::tryAcquire() {
  if (hasAcquiredRecord()) {
    throw std::logic_error("A record is already acquired from this ring buffer.");
  }

  while (true) {
    const auto currentReadCursor = readCursor(bytes).load(std::memory_order_relaxed);
    const auto currentWriteCursor = writeCursor(bytes).load(std::memory_order_acquire);
    const auto availableByteCount = currentWriteCursor - currentReadCursor;

    if (availableByteCount == 0) {
      return std::nullopt;
    }

    if (availableByteCount > dataCapacity) {
      throw std::runtime_error("Record ring buffer cursors are invalid.");
    }

    const auto readOffset = currentReadCursor % dataCapacity;
    const auto contiguousByteCount = dataCapacity - readOffset;

    if (contiguousByteCount < recordHeaderSize) {
      if (availableByteCount < contiguousByteCount) {
        throw std::runtime_error("Record ring buffer wrap padding is incomplete.");
      }

      readCursor(bytes).store(currentReadCursor + contiguousByteCount, std::memory_order_release);
      continue;
    }

    const auto recordLength = readRecordLength(data(bytes) + readOffset);
    if (recordLength == wrapMarker) {
      if (availableByteCount < contiguousByteCount) {
        throw std::runtime_error("Record ring buffer wrap marker is incomplete.");
      }

      readCursor(bytes).store(currentReadCursor + contiguousByteCount, std::memory_order_release);
      continue;
    }

    const auto recordByteCount = recordHeaderSize + static_cast<std::size_t>(recordLength);
    if (recordLength > maximumRecordSize() || recordByteCount > contiguousByteCount ||
        recordByteCount > availableByteCount) {
      throw std::runtime_error("Record ring buffer contains an invalid record.");
    }

    acquiredReadCursor = currentReadCursor;
    acquiredByteCount = static_cast<std::uint32_t>(recordByteCount);
    currentRecord =
        std::span<const std::byte>(data(bytes) + readOffset + recordHeaderSize, recordLength);
    return currentRecord;
  }
}

std::span<const std::byte> SpscRecordRingBufferReader::acquiredRecord() const {
  if (!hasAcquiredRecord()) {
    throw std::logic_error("No record is currently acquired from this ring buffer.");
  }

  return currentRecord;
}

bool SpscRecordRingBufferReader::hasAcquiredRecord() const noexcept {
  return acquiredByteCount != 0;
}

std::size_t SpscRecordRingBufferReader::availableBytes() const noexcept {
  const auto written = writeCursor(bytes).load(std::memory_order_acquire);
  const auto read = readCursor(bytes).load(std::memory_order_relaxed);
  return std::min(written - read, dataCapacity);
}

void SpscRecordRingBufferReader::release() {
  if (!hasAcquiredRecord()) {
    throw std::logic_error("No record is currently acquired from this ring buffer.");
  }

  readCursor(bytes).store(acquiredReadCursor + acquiredByteCount, std::memory_order_release);
  acquiredReadCursor = 0;
  acquiredByteCount = 0;
  currentRecord = {};
}

std::size_t SpscRecordRingBufferReader::maximumRecordSize() const noexcept {
  return ::anthem::ipc::maximumRecordSize(dataCapacity);
}

} // namespace anthem::ipc
