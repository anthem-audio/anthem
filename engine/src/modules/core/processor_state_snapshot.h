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

#pragma once

#include "file_storage_client.h"
#include "modules/processing_graph/processor/processor.h"

namespace anthem {

// A snapshot contains common base settings followed by the processor's private
// payload.
class ProcessorStateSnapshot {
public:
  explicit ProcessorStateSnapshot(Processor& processor);
  explicit ProcessorStateSnapshot(const juce::File& file);
  bool isEmpty() const;
  FileFingerprint fingerprint() const;
  void write(const juce::File& file) const;
  void restore(Processor& processor) const;
private:
  std::map<int64_t, double> parameters;
  juce::MemoryBlock privateState;
  juce::MemoryBlock prefix;
  void buildPrefix();
};

} // namespace anthem
