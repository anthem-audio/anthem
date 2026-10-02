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

#include "visualization_provider.h"

#include <anthem_native_ipc/spsc_record_ring_buffer.h>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <vector>

namespace anthem {

constexpr std::size_t maximumVisualizationRecordBytes = 1024 * 1024;

struct VisualizationRecordItem {
  std::string id;
  VisualizationDataPayload data;
};

struct VisualizationRecordMetadata {
  std::uint32_t sequence;
  std::uint64_t generation;
  double sampleRate;
  std::int64_t newestSampleTimestamp;
};

// Wire format v1 uses explicit little-endian fields, never native struct layout.
// See docs/architecture/communication_between_ui_and_engine.md.
std::optional<std::vector<std::byte>> encodeVisualizationRecord(
    const VisualizationRecordMetadata& metadata,
    std::span<const VisualizationRecordItem> items,
    std::size_t maximumBytes = maximumVisualizationRecordBytes);

// Message-thread publisher. A full ring retains one coalesced update, including
// the final value of providers which produce no further samples.
class VisualizationRecordPublisher {
private:
  std::vector<VisualizationRecordItem> pendingItems;
  std::optional<std::uint64_t> generation;
  std::uint32_t sequence = 0;
public:
  std::uint64_t publishedRecords = 0;
  std::uint64_t rejectedWrites = 0;
  std::uint64_t oversizedUpdates = 0;

  void publish(ipc::SpscRecordRingBufferWriter& writer,
      std::uint64_t generation,
      double sampleRate,
      std::vector<VisualizationRecordItem> items);
  void reset();
  void discard(const std::string& id);
};

} // namespace anthem
