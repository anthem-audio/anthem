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
#include "modules/core/visualization/visualization_record.h"

#include <bit>
#include <cstring>
#include <juce_core/juce_core.h>
#include <vector>

namespace anthem {
class VisualizationRecordTest : public juce::UnitTest {
public:
  VisualizationRecordTest() : juce::UnitTest("VisualizationRecordTest", "Anthem") {}
  void runTest() override {
    beginTest("Binary records match the shared Dart/C++ fixture");
    const std::vector<VisualizationRecordItem> items{
        {"d-\xce\xa9", NumericVisualizationData{{10, 20}, {-0.0, 1.5}}},
        {"i", IntegerVisualizationData{{10, 20}, {-7, 9007199254740991LL}}},
    };
    const auto bytes = encodeVisualizationRecord({7, 9, 48000, 20}, items);
    const auto hex = juce::File(ANTHEM_TEST_FIXTURES_DIR "/visualization_record_v1.hex")
                         .loadFileAsString()
                         .trim()
                         .toStdString();
    expect(!hex.empty(), "The common fixture must be available.");
    expect(bytes.has_value());
    if (bytes.has_value()) {
      expectEquals(bytes->size() * 2, hex.size());
      for (std::size_t i = 0; i < bytes->size() && i * 2 + 1 < hex.size(); ++i)
        expectEquals(static_cast<int>((*bytes)[i]), std::stoi(hex.substr(i * 2, 2), nullptr, 16));
    }

    beginTest("Encoding rejects oversized and mismatched batches");
    expect(!encodeVisualizationRecord({7, 9, 48000, 20}, items, 40).has_value());
    const std::vector<VisualizationRecordItem> invalid{
        {"bad", NumericVisualizationData{{10}, {1.0, 2.0}}}};
    expect(!encodeVisualizationRecord({7, 9, 48000, 20}, invalid).has_value());

    beginTest("A full ring retains the newest final value and bounds history");
    std::vector<std::uint32_t> storage(96);
    std::span<std::byte> region(reinterpret_cast<std::byte*>(storage.data()), storage.size() * 4);
    ipc::initializeSpscRecordRingBuffer(region);
    ipc::SpscRecordRingBufferWriter writer(region);
    ipc::SpscRecordRingBufferReader reader(region);
    std::vector<std::byte> filler(8);
    while (writer.tryWrite(filler)) {
    }
    VisualizationRecordPublisher publisher;
    publisher.publish(writer, 1, 1000, {{"d", NumericVisualizationData{{0, 100}, {8.0, 1.0}}}});
    publisher.publish(writer, 1, 1000, {{"d", NumericVisualizationData{{1000}, {3.0}}}});
    expectEquals(publisher.rejectedWrites, std::uint64_t{2});
    while (reader.tryAcquire().has_value())
      reader.release();
    publisher.publish(writer, 1, 1000, {});
    expectEquals(publisher.publishedRecords, std::uint64_t{1});
    const auto acquired = reader.tryAcquire();
    expect(acquired.has_value());
    if (acquired.has_value()) {
      // Header (40), item header (12), "d" (1), timestamp (8), value (8).
      expectEquals(acquired->size(), std::size_t{69});
      if (acquired->size() == 69) {
        std::uint64_t value = 0;
        std::memcpy(&value, acquired->data() + 61, 8);
        expectEquals(std::bit_cast<double>(value), 3.0);
      }
      reader.release();
    }
    publisher.publish(writer, 1, 1000, {});
    expect(!reader.tryAcquire().has_value(), "A successful retry clears the pending snapshot.");

    beginTest("Session changes and provider removal discard unsent data");
    while (writer.tryWrite(filler)) {
    }
    publisher.publish(writer, 1, 1000, {{"d", NumericVisualizationData{{2000}, {4.0}}}});
    publisher.discard("d");
    while (reader.tryAcquire().has_value())
      reader.release();
    publisher.publish(writer, 1, 1000, {});
    expect(!reader.tryAcquire().has_value());
    while (writer.tryWrite(filler)) {
    }
    publisher.publish(writer, 1, 1000, {{"d", NumericVisualizationData{{2000}, {5.0}}}});
    while (reader.tryAcquire().has_value())
      reader.release();
    publisher.publish(writer, 2, 1000, {});
    expect(!reader.tryAcquire().has_value());

    beginTest("Oversized numeric history retains its peak and final value");
    publisher.publish(writer,
        3,
        48000,
        {{"d", NumericVisualizationData{{1000, 1001, 1002, 1003, 1004}, {9, 20, 1, 0, 2}}}});
    expectEquals(publisher.oversizedUpdates, std::uint64_t{1});
    const auto compacted = reader.tryAcquire();
    expect(compacted.has_value());
    if (compacted.has_value()) {
      expectEquals(compacted->size(), std::size_t{85});
      if (compacted->size() == 85) {
        std::uint64_t peak = 0, finalValue = 0;
        std::memcpy(&peak, compacted->data() + 61, 8);
        std::memcpy(&finalValue, compacted->data() + 77, 8);
        expectEquals(std::bit_cast<double>(peak), 20.0);
        expectEquals(std::bit_cast<double>(finalValue), 2.0);
      }
      reader.release();
    }
  }
};
static VisualizationRecordTest visualizationRecordTest;
} // namespace anthem
