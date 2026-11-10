/*
  Copyright (C) 2024 - 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

#include "processor_state_snapshot.h"

#include <array>
#include <cmath>
#include <cstring>
#include <juce_cryptography/juce_cryptography.h>
#include <rfl/json.hpp>
#include <stdexcept>

namespace anthem {
namespace {
constexpr char magic[] = "ANTHST01";
constexpr int magicLength = 8;
constexpr int maximumMetadataLength = 16 * 1024 * 1024;

struct SnapshotMetadata {
  int version = 1;
  std::map<std::string, double> parameters;
};

// Hash and write the header and private payload as one stream, without making
// another complete copy of a potentially large plugin state allocation.
class SnapshotInputStream : public juce::InputStream {
public:
  SnapshotInputStream(const juce::MemoryBlock& prefix, const juce::MemoryBlock& payload)
    : parts{&prefix, &payload} {}
  juce::int64 getTotalLength() override {
    return static_cast<juce::int64>(parts[0]->getSize()) +
           static_cast<juce::int64>(parts[1]->getSize());
  }
  juce::int64 getPosition() override {
    return position;
  }
  bool setPosition(juce::int64 value) override {
    if (value < 0 || value > getTotalLength())
      return false;
    position = value;
    return true;
  }
  bool isExhausted() override {
    return position == getTotalLength();
  }
  int read(void* destination, int requested) override {
    int copied = 0;
    juce::int64 start = 0;
    for (const auto* part : parts) {
      const auto end = start + static_cast<juce::int64>(part->getSize());
      if (position >= start && position < end && copied < requested) {
        const auto count =
            static_cast<int>(juce::jmin<juce::int64>(end - position, requested - copied));
        std::memcpy(static_cast<char*>(destination) + copied,
            static_cast<const char*>(part->getData()) + (position - start),
            static_cast<size_t>(count));
        position += count;
        copied += count;
      }
      start = end;
    }
    return copied;
  }
private:
  std::array<const juce::MemoryBlock*, 2> parts;
  juce::int64 position = 0;
};
} // namespace

ProcessorStateSnapshot::ProcessorStateSnapshot(Processor& processor) {
  for (const auto& value : processor.getParameterValues())
    parameters.emplace(value.controlPortId, value.value);
  processor.getState(privateState);
  buildPrefix();
}

ProcessorStateSnapshot::ProcessorStateSnapshot(const juce::File& file) {
  juce::FileInputStream input(file);
  char signature[magicLength];
  if (!input.openedOk() || input.read(signature, magicLength) != magicLength ||
      std::memcmp(signature, magic, magicLength) != 0)
    throw std::runtime_error("Invalid processor state file header.");
  const auto length = input.readInt();
  if (length <= 0 || length > maximumMetadataLength ||
      length > input.getTotalLength() - input.getPosition())
    throw std::runtime_error("Invalid processor state metadata length.");
  juce::MemoryBlock metadataBytes;
  if (input.readIntoMemoryBlock(metadataBytes, length) != length)
    throw std::runtime_error("Could not read processor state metadata.");
  const auto metadata = rfl::json::read<SnapshotMetadata>(
      std::string(static_cast<const char*>(metadataBytes.getData()), metadataBytes.getSize()));
  if (!metadata || metadata.value().version != 1)
    throw std::runtime_error("Unsupported or invalid processor state metadata.");
  for (const auto& [key, value] : metadata.value().parameters) {
    size_t consumed = 0;
    const auto id = std::stoll(key, &consumed);
    if (consumed != key.size() || !std::isfinite(value) || value < 0.0 || value > 1.0)
      throw std::runtime_error("Invalid stored processor parameter.");
    parameters.emplace(id, value);
  }
  const auto remaining = input.getTotalLength() - input.getPosition();
  if (input.readIntoMemoryBlock(privateState, remaining) != remaining)
    throw std::runtime_error("Could not read processor-specific state.");
  buildPrefix();
}

void ProcessorStateSnapshot::buildPrefix() {
  SnapshotMetadata metadata;
  for (const auto& [id, value] : parameters)
    metadata.parameters.emplace(std::to_string(id), value);
  const auto json = rfl::json::write(metadata);
  if (json.size() > maximumMetadataLength)
    throw std::runtime_error("Processor parameter metadata is too large to store.");
  juce::MemoryOutputStream output(prefix, false);
  output.write(magic, magicLength);
  output.writeInt(static_cast<int>(json.size()));
  output.write(json.data(), json.size());
}

bool ProcessorStateSnapshot::isEmpty() const {
  return parameters.empty() && privateState.getSize() == 0;
}

FileFingerprint ProcessorStateSnapshot::fingerprint() const {
  SnapshotInputStream input(prefix, privateState);
  return {.byteLength = input.getTotalLength(),
      .sha256 = juce::SHA256(input).toHexString().toStdString()};
}

void ProcessorStateSnapshot::write(const juce::File& file) const {
  juce::FileOutputStream output(file);
  if (!output.openedOk() || !output.setPosition(0) || output.truncate().failed())
    throw std::runtime_error("Could not open captured processor state file.");
  SnapshotInputStream input(prefix, privateState);
  if (output.writeFromInputStream(input, -1) != input.getTotalLength())
    throw std::runtime_error("Could not write captured processor state.");
  output.flush();
  if (output.getStatus().failed())
    throw std::runtime_error("Could not flush captured processor state.");
}

void ProcessorStateSnapshot::restore(Processor& processor) const {
  if (privateState.getSize() != 0)
    processor.setState(privateState);
  processor.restoreParameterValues(parameters);
}

} // namespace anthem
