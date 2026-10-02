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
#include <memory>
#include <optional>
#include <string>

#ifdef __EMSCRIPTEN__
#include <cstdint>
#include <vector>
#else
#include <anthem_native_ipc/shared_memory_region.h>
#endif // #ifdef __EMSCRIPTEN__

namespace anthem {

// Owns the visualization communication channel for the engine's lifetime.
// Subscription management, encoding, and batching belong to the broker/publisher.
class VisualizationComms {
private:
  // Storage must outlive the ring endpoints, which borrow views of its bytes.
#ifdef __EMSCRIPTEN__
  std::vector<std::uint32_t> ringBufferStorage;
#else
  std::unique_ptr<ipc::SharedMemoryRegion> sharedMemory;
#endif // #ifdef __EMSCRIPTEN__

  std::unique_ptr<ipc::SpscRecordRingBufferWriter> writer;

#ifdef __EMSCRIPTEN__
  std::unique_ptr<ipc::SpscRecordRingBufferReader> reader;
#endif // #ifdef __EMSCRIPTEN__
public:
  // Attaches to the UI's desktop mapping, or creates the ring in WASM memory.
  // An error is reported through the engine's bootstrap/ready-check handshake.
  std::optional<std::string> init() noexcept;

  // Borrowed by the message-thread publisher. Null before initialization.
  ipc::SpscRecordRingBufferWriter* getWriter() noexcept {
    return writer.get();
  }

#ifdef __EMSCRIPTEN__
  // Borrowed by the exported functions called from the Dart UI isolate.
  ipc::SpscRecordRingBufferReader* getReader() noexcept {
    return reader.get();
  }
#endif // #ifdef __EMSCRIPTEN__
};

} // namespace anthem
