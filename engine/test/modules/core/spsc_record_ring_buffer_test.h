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

#include <anthem_native_ipc/spsc_record_ring_buffer.h>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <juce_core/juce_core.h>
#include <limits>
#include <span>
#include <stdexcept>
#include <thread>
#include <vector>

namespace anthem {

class SpscRecordRingBufferTest : public juce::UnitTest {
public:
  SpscRecordRingBufferTest() : juce::UnitTest("SpscRecordRingBufferTest", "Anthem") {}

  void runTest() override {
    testRecordsRemainOrderedAndAcquiredUntilRelease();
    testWrapAndFullBufferBehavior();
    testConcurrentReaderAndWriter();
    testCursorRollover();
    testInvalidRecord();
  }
private:
  void testCursorRollover() {
    beginTest("Records survive uint32 cursor rollover with non-power-of-two storage");
    std::vector<std::uint32_t> storage(72);
    auto bytes = asBytes(storage);
    ipc::initializeSpscRecordRingBuffer(bytes);
    const auto cursor = std::numeric_limits<std::uint32_t>::max() - 23;
    storage[0] = cursor;
    storage[16] = cursor;
    ipc::SpscRecordRingBufferWriter writer(bytes);
    ipc::SpscRecordRingBufferReader reader(bytes);
    const std::vector<std::uint8_t> first(20, 7);
    const std::vector<std::uint8_t> second(8, 9);
    expect(writer.tryWrite(asBytes(first)));
    expect(writer.tryWrite(asBytes(second)));
    expectRecord(reader, first);
    reader.release();
    expectRecord(reader, second);
    reader.release();
    expect(!reader.tryAcquire().has_value());
    const std::vector<std::uint8_t> maximum(writer.maximumRecordSize(), 5);
    expect(writer.tryWrite(asBytes(maximum)));
    expectRecord(reader, maximum);
    reader.release();
  }

  void testInvalidRecord() {
    beginTest("Malformed records are rejected without advancing the reader");
    std::vector<std::uint32_t> storage(64);
    auto bytes = asBytes(storage);
    ipc::initializeSpscRecordRingBuffer(bytes);
    storage[16] = 8;
    storage[32] = 100;
    ipc::SpscRecordRingBufferReader reader(bytes);
    bool rejected = false;
    try {
      (void)reader.tryAcquire();
    } catch (const std::runtime_error&) {
      rejected = true;
    }
    expect(rejected);
    expectEquals(storage[0], std::uint32_t{0});
    expect(!reader.hasAcquiredRecord());
  }

  static std::span<std::byte> asBytes(std::vector<std::uint32_t>& storage) {
    return {reinterpret_cast<std::byte*>(storage.data()), storage.size() * sizeof(std::uint32_t)};
  }

  static std::span<const std::byte> asBytes(const std::vector<std::uint8_t>& record) {
    return {reinterpret_cast<const std::byte*>(record.data()), record.size()};
  }

  void expectRecord(
      ipc::SpscRecordRingBufferReader& reader, const std::vector<std::uint8_t>& expected) {
    const auto acquired = reader.tryAcquire();
    expect(acquired.has_value(), "A record should be available.");
    if (!acquired.has_value()) {
      return;
    }

    expectEquals(acquired->size(), expected.size());
    if (acquired->size() == expected.size()) {
      expect(std::memcmp(acquired->data(), expected.data(), expected.size()) == 0,
          "The acquired record should match the written bytes.");
    }
  }

  void testRecordsRemainOrderedAndAcquiredUntilRelease() {
    beginTest("Records remain ordered and acquired until release");

    std::vector<std::uint32_t> storage(64);
    auto bytes = asBytes(storage);
    ipc::initializeSpscRecordRingBuffer(bytes);
    ipc::SpscRecordRingBufferWriter writer(bytes);
    ipc::SpscRecordRingBufferReader reader(bytes);

    const std::vector<std::uint8_t> first{1, 2, 3};
    const std::vector<std::uint8_t> second{4, 5};
    expect(writer.tryWrite(asBytes(first)));
    expect(writer.tryWrite(asBytes(second)));

    expectRecord(reader, first);
    expect(reader.hasAcquiredRecord());

    bool didRejectSecondAcquire = false;
    try {
      (void)reader.tryAcquire();
    } catch (const std::logic_error&) {
      didRejectSecondAcquire = true;
    }
    expect(didRejectSecondAcquire, "A second acquire should require releasing the first record.");

    reader.release();
    expectRecord(reader, second);
    reader.release();
    expect(!reader.tryAcquire().has_value(), "The ring should be empty after both releases.");
  }

  void testWrapAndFullBufferBehavior() {
    beginTest("Records wrap contiguously and new records are dropped when full");

    std::vector<std::uint32_t> storage(64);
    auto bytes = asBytes(storage);
    ipc::initializeSpscRecordRingBuffer(bytes);
    ipc::SpscRecordRingBufferWriter writer(bytes);
    ipc::SpscRecordRingBufferReader reader(bytes);

    const std::vector<std::uint8_t> smallRecord(20, 7);
    for (int index = 0; index < 5; ++index) {
      expect(writer.tryWrite(asBytes(smallRecord)));
    }
    expect(
        !writer.tryWrite(asBytes(smallRecord)), "A full ring should reject the entire new record.");

    for (int index = 0; index < 3; ++index) {
      expectRecord(reader, smallRecord);
      reader.release();
    }

    const std::vector<std::uint8_t> wrappedRecord(36, 9);
    expect(writer.tryWrite(asBytes(wrappedRecord)), "The record should fit after wrapping.");

    for (int index = 0; index < 2; ++index) {
      expectRecord(reader, smallRecord);
      reader.release();
    }
    expectRecord(reader, wrappedRecord);
    reader.release();
    expect(!reader.tryAcquire().has_value());

    const std::vector<std::uint8_t> oversizedRecord(writer.maximumRecordSize() + 1, 0);
    expect(!writer.tryWrite(asBytes(oversizedRecord)),
        "A record larger than the supported maximum should be rejected.");
  }

  void testConcurrentReaderAndWriter() {
    beginTest("Reader and writer exchange records concurrently");

    std::vector<std::uint32_t> storage(1024);
    auto bytes = asBytes(storage);
    ipc::initializeSpscRecordRingBuffer(bytes);
    ipc::SpscRecordRingBufferWriter writer(bytes);
    ipc::SpscRecordRingBufferReader reader(bytes);

    constexpr std::uint32_t recordCount = 10000;
    std::atomic<bool> failed = false;

    std::thread writerThread([&]() {
      for (std::uint32_t value = 0; value < recordCount; ++value) {
        const auto record = std::as_bytes(std::span(&value, 1));
        while (!writer.tryWrite(record)) {
          std::this_thread::yield();
        }
      }
    });

    std::thread readerThread([&]() {
      for (std::uint32_t expected = 0; expected < recordCount; ++expected) {
        std::optional<std::span<const std::byte>> record;
        while (!(record = reader.tryAcquire()).has_value()) {
          std::this_thread::yield();
        }

        std::uint32_t actual = 0;
        if (record->size() != sizeof(actual)) {
          failed.store(true);
        } else {
          std::memcpy(&actual, record->data(), sizeof(actual));
          if (actual != expected) {
            failed.store(true);
          }
        }
        reader.release();
      }
    });

    writerThread.join();
    readerThread.join();

    expect(!failed.load(), "All records should arrive intact and in order.");
  }
};

static SpscRecordRingBufferTest spscRecordRingBufferTest;

} // namespace anthem
