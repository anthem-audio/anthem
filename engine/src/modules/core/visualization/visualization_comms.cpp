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

#include "visualization_comms.h"

#include <charconv>
#include <cstddef>
#include <cstdint>
#include <juce_core/juce_core.h>
#include <limits>
#include <span>
#include <stdexcept>

namespace anthem {

std::optional<std::string> VisualizationComms::init() noexcept {
  try {
#ifdef __EMSCRIPTEN__
    constexpr std::size_t ringBufferSize = 16 * 1024 * 1024 + 128;
    static_assert(ringBufferSize % sizeof(std::uint32_t) == 0);
    ringBufferStorage.resize(ringBufferSize / sizeof(std::uint32_t));
    auto bytes = std::span<std::byte>(
        reinterpret_cast<std::byte*>(ringBufferStorage.data()), ringBufferSize);
    ipc::initializeSpscRecordRingBuffer(bytes);
    writer = std::make_unique<ipc::SpscRecordRingBufferWriter>(bytes);
    reader = std::make_unique<ipc::SpscRecordRingBufferReader>(bytes);
#else
    constexpr auto identifierEnvironmentKey = "ANTHEM_VISUALIZATION_SHARED_MEMORY_IDENTIFIER";
    constexpr auto sizeEnvironmentKey = "ANTHEM_VISUALIZATION_SHARED_MEMORY_SIZE";

    const auto identifier =
        juce::SystemStats::getEnvironmentVariable(identifierEnvironmentKey, "").toStdString();
    const auto sizeString =
        juce::SystemStats::getEnvironmentVariable(sizeEnvironmentKey, "").toStdString();

    if (identifier.empty()) {
      throw std::invalid_argument(
          std::string(identifierEnvironmentKey) + " was not provided in the environment.");
    }

    uint64_t size = 0;
    const auto parseResult =
        std::from_chars(sizeString.data(), sizeString.data() + sizeString.size(), size);
    if (sizeString.empty() || parseResult.ec != std::errc{} ||
        parseResult.ptr != sizeString.data() + sizeString.size() || size == 0 ||
        size > std::numeric_limits<std::size_t>::max()) {
      throw std::invalid_argument(std::string(sizeEnvironmentKey) + " is invalid.");
    }

    sharedMemory = std::make_unique<ipc::SharedMemoryRegion>(
        ipc::SharedMemoryRegion::open(identifier, static_cast<std::size_t>(size)));
    writer = std::make_unique<ipc::SpscRecordRingBufferWriter>(sharedMemory->bytes());
#endif // #ifdef __EMSCRIPTEN__

    juce::Logger::writeToLog("Initialized the visualization record ring.");
    return std::nullopt;
  } catch (const std::exception& exception) {
    auto error = std::string(exception.what());
    juce::Logger::writeToLog("Failed to initialize the visualization transport: " + error);
    return error;
  } catch (...) {
    auto error = std::string("Unknown error while initializing the visualization transport.");
    juce::Logger::writeToLog(error);
    return error;
  }
}

} // namespace anthem
