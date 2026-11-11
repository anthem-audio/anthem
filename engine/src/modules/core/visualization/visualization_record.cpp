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

#include "visualization_record.h"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>
#include <type_traits>
#include <utility>

namespace anthem {
namespace {
constexpr std::uint32_t magic = 0x31564941; // "AIV1"
constexpr std::size_t headerSize = 40;

void append32(std::vector<std::byte>& bytes, std::uint32_t value) {
  for (int shift = 0; shift < 32; shift += 8)
    bytes.push_back(static_cast<std::byte>((value >> shift) & 0xff));
}
void append64(std::vector<std::byte>& bytes, std::uint64_t value) {
  for (int shift = 0; shift < 64; shift += 8)
    bytes.push_back(static_cast<std::byte>((value >> shift) & 0xff));
}
void appendText(std::vector<std::byte>& bytes, const std::string& value) {
  const auto* start = reinterpret_cast<const std::byte*>(value.data());
  bytes.insert(bytes.end(), start, start + value.size());
}

std::int64_t newestTimestamp(std::span<const VisualizationRecordItem> items) {
  std::int64_t newest = 0;
  for (const auto& item : items)
    std::visit(
        [&](const auto& batch) {
          if (!batch.sampleTimestamps.empty())
            newest = std::max(newest, batch.sampleTimestamps.back());
        },
        item.data);
  return newest;
}

void trimHistory(VisualizationRecordItem& item, std::int64_t cutoff) {
  std::visit(
      [&](auto& batch) {
        if (batch.values.empty())
          return;
        const auto keepFrom = std::min<std::size_t>(
            std::lower_bound(batch.sampleTimestamps.begin(), batch.sampleTimestamps.end(), cutoff) -
                batch.sampleTimestamps.begin(),
            batch.values.size() - 1);
        batch.sampleTimestamps.erase(
            batch.sampleTimestamps.begin(), batch.sampleTimestamps.begin() + keepFrom);
        batch.values.erase(batch.values.begin(), batch.values.begin() + keepFrom);
      },
      item.data);
}

void retainLatestAndPeak(VisualizationRecordItem& item) {
  std::visit(
      [](auto& batch) {
        if (batch.values.empty())
          return;
        using Batch = std::remove_cvref_t<decltype(batch)>;
        const auto last = batch.values.size() - 1;
        if constexpr (std::is_same_v<Batch, NumericVisualizationData>) {
          const auto peak = static_cast<std::size_t>(
              std::max_element(batch.values.begin(), batch.values.end()) - batch.values.begin());
          if (peak != last) {
            batch = Batch{{batch.sampleTimestamps[peak], batch.sampleTimestamps[last]},
                {batch.values[peak], batch.values[last]}};
            return;
          }
        }
        batch = Batch{{batch.sampleTimestamps[last]}, {batch.values[last]}};
      },
      item.data);
}
} // namespace

std::optional<std::vector<std::byte>> encodeVisualizationRecord(
    const VisualizationRecordMetadata& metadata,
    std::span<const VisualizationRecordItem> items,
    std::size_t maximumBytes) {
  if (maximumBytes < headerSize || !std::isfinite(metadata.sampleRate) ||
      metadata.sampleRate <= 0 || metadata.sampleRate > 1000000 ||
      metadata.newestSampleTimestamp < 0 ||
      items.size() > std::numeric_limits<std::uint32_t>::max())
    return std::nullopt;

  std::size_t size = headerSize;
  const auto addSize = [&](std::size_t count) {
    if (count > maximumBytes - size)
      return false;
    size += count;
    return true;
  };
  for (const auto& item : items) {
    if (item.id.empty() || item.id.size() > 4096 || !addSize(12) || !addSize(item.id.size()))
      return std::nullopt;
    const bool valid = std::visit(
        [&](const auto& batch) {
          if (batch.values.size() != batch.sampleTimestamps.size() || batch.values.size() > 2048 ||
              !std::is_sorted(batch.sampleTimestamps.begin(), batch.sampleTimestamps.end()) ||
              !addSize(batch.values.size() * 16))
            return false;
          for (const auto timestamp : batch.sampleTimestamps) {
            if (timestamp < 0 || timestamp > metadata.newestSampleTimestamp)
              return false;
          }
          return true;
        },
        item.data);
    if (!valid)
      return std::nullopt;
  }

  std::vector<std::byte> bytes;
  bytes.reserve(size);
  append32(bytes, magic);
  append32(bytes, 1);
  append32(bytes, metadata.sequence);
  append64(bytes, metadata.generation);
  append64(bytes, std::bit_cast<std::uint64_t>(metadata.sampleRate));
  append64(bytes, std::bit_cast<std::uint64_t>(metadata.newestSampleTimestamp));
  append32(bytes, static_cast<std::uint32_t>(items.size()));
  for (const auto& item : items) {
    append32(bytes, static_cast<std::uint32_t>(item.id.size()));
    append32(bytes, static_cast<std::uint32_t>(item.data.index()));
    std::visit(
        [&](const auto& batch) {
          append32(bytes, static_cast<std::uint32_t>(batch.values.size()));
          appendText(bytes, item.id);
          for (std::size_t i = 0; i < batch.values.size(); ++i) {
            append64(bytes, std::bit_cast<std::uint64_t>(batch.sampleTimestamps[i]));
            append64(bytes, std::bit_cast<std::uint64_t>(batch.values[i]));
          }
        },
        item.data);
  }
  return bytes;
}

void VisualizationRecordPublisher::publish(ipc::SpscRecordRingBufferWriter& writer,
    std::uint64_t newGeneration,
    double sampleRate,
    std::vector<VisualizationRecordItem> items) {
  if (!std::isfinite(sampleRate) || sampleRate <= 0 || sampleRate > 1000000) {
    reset();
    return;
  }
  if (generation != newGeneration) {
    pendingItems.clear();
    generation = newGeneration;
  }
  for (auto& item : items) {
    const auto existing = std::find_if(pendingItems.begin(),
        pendingItems.end(),
        [&](const auto& pending) { return pending.id == item.id; });
    if (existing == pendingItems.end()) {
      pendingItems.push_back(std::move(item));
      continue;
    }
    std::visit(
        [&](auto& incoming) {
          using Batch = std::remove_cvref_t<decltype(incoming)>;
          auto* previous = std::get_if<Batch>(&existing->data);
          if (previous == nullptr || previous->values.empty() || incoming.values.empty() ||
              incoming.sampleTimestamps.front() < previous->sampleTimestamps.back()) {
            existing->data = std::move(incoming);
            return;
          }
          previous->values.insert(previous->values.end(),
              std::make_move_iterator(incoming.values.begin()),
              std::make_move_iterator(incoming.values.end()));
          previous->sampleTimestamps.insert(previous->sampleTimestamps.end(),
              incoming.sampleTimestamps.begin(),
              incoming.sampleTimestamps.end());
        },
        item.data);
  }
  if (pendingItems.empty())
    return;

  const auto newest = newestTimestamp(pendingItems);
  const auto cutoff = newest - static_cast<std::int64_t>(sampleRate * 0.25);
  for (auto& item : pendingItems)
    trimHistory(item, cutoff);
  const auto metadata = VisualizationRecordMetadata{++sequence, newGeneration, sampleRate, newest};
  const auto limit = std::min(maximumVisualizationRecordBytes, writer.maximumRecordSize());
  auto bytes = encodeVisualizationRecord(metadata, pendingItems, limit);
  if (!bytes.has_value()) {
    ++oversizedUpdates;
    for (auto& item : pendingItems)
      retainLatestAndPeak(item);
    bytes = encodeVisualizationRecord(metadata, pendingItems, limit);
    // An oversized ID or a subscription set larger than the ring cannot
    // be allowed to retain unbounded memory or prevent all other items publishing.
    while (!bytes.has_value() && !pendingItems.empty()) {
      pendingItems.pop_back();
      bytes = encodeVisualizationRecord(metadata, pendingItems, limit);
    }
  }
  if (pendingItems.empty() || !bytes.has_value())
    return;
  if (writer.tryWrite(*bytes)) {
    ++publishedRecords;
    pendingItems.clear();
  } else {
    ++rejectedWrites;
  }
}

void VisualizationRecordPublisher::reset() {
  pendingItems.clear();
  generation.reset();
}

void VisualizationRecordPublisher::discard(const std::string& id) {
  std::erase_if(pendingItems, [&](const auto& item) { return item.id == id; });
}
} // namespace anthem
