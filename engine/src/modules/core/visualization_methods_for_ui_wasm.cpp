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

#ifdef __EMSCRIPTEN__

#include "visualization_methods_for_ui_wasm.h"

#include "engine.h"

#include <exception>
#include <juce_core/juce_core.h>

namespace {

anthem::ipc::SpscRecordRingBufferReader* getReader() noexcept {
  if (!anthem::Engine::hasInstance()) {
    return nullptr;
  }
  return anthem::Engine::getInstance().visualizationComms.getReader();
}

} // namespace

int32_t tryAcquireVisualizationRecord() noexcept {
  auto* reader = getReader();
  if (reader == nullptr) {
    return -1;
  }

  try {
    return reader->tryAcquire().has_value() ? 1 : 0;
  } catch (const std::exception& error) {
    juce::Logger::writeToLog(
        "Failed to acquire a visualization record: " + juce::String(error.what()));
  } catch (...) {
    juce::Logger::writeToLog("Unknown error while acquiring a visualization record.");
  }

  return -1;
}

const void* getAcquiredVisualizationRecordData() noexcept {
  auto* reader = getReader();
  if (reader == nullptr || !reader->hasAcquiredRecord()) {
    return nullptr;
  }
  return reader->acquiredRecord().data();
}

uint32_t getAcquiredVisualizationRecordSize() noexcept {
  auto* reader = getReader();
  if (reader == nullptr || !reader->hasAcquiredRecord()) {
    return 0;
  }
  return static_cast<uint32_t>(reader->acquiredRecord().size());
}

int32_t releaseVisualizationRecord() noexcept {
  auto* reader = getReader();
  if (reader == nullptr) {
    return 0;
  }

  try {
    reader->release();
    return 1;
  } catch (const std::exception& error) {
    juce::Logger::writeToLog(
        "Failed to release a visualization record: " + juce::String(error.what()));
  } catch (...) {
    juce::Logger::writeToLog("Unknown error while releasing a visualization record.");
  }

  return 0;
}

uint32_t getVisualizationRecordAvailableBytes() noexcept {
  auto* reader = getReader();
  return reader == nullptr ? 0 : static_cast<uint32_t>(reader->availableBytes());
}

#endif // #ifdef __EMSCRIPTEN__
