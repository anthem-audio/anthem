/*
  Copyright (C) 2026 Joshua Wade

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

#include "modules/processing_graph/runtime/audio_buffer_slice.h"

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <vector>

namespace anthem {

class Node;
class NodeProcessContext;
class Processor;

enum class RuntimeConnectionDataType : uint8_t {
  audio,
  control,
  event,
};

struct RuntimeConnectionTransferAction {
  // Precomputed graph-owned buffer references for an input that cannot alias
  // its source directly. Audio uses slices so transfers only touch channels
  // that belong to the connected ports; control/event use whole buffer indices.
  RuntimeConnectionDataType dataType;
  size_t destinationBufferIndex = 0;
  std::vector<size_t> sourceBufferIndices;

  AudioBufferSlice destinationAudioSlice;
  std::vector<AudioBufferSlice> sourceAudioSlices;
};

struct RuntimeNodeState {
  RuntimeNodeState() = default;
  RuntimeNodeState(const RuntimeNodeState&) = delete;
  RuntimeNodeState& operator=(const RuntimeNodeState&) = delete;

  RuntimeNodeState(RuntimeNodeState&& other) noexcept;
  RuntimeNodeState& operator=(RuntimeNodeState&& other) noexcept;

  std::atomic<size_t> rt_remainingUpstreamNodes = 0;
};

struct RuntimeNode {
  using Id = int64_t;

  RuntimeNode() = default;
  RuntimeNode(Id id, std::shared_ptr<anthem::Node> sourceNode);

  RuntimeNode(const RuntimeNode&) = delete;
  RuntimeNode& operator=(const RuntimeNode&) = delete;

  RuntimeNode(RuntimeNode&& other) noexcept;
  RuntimeNode& operator=(RuntimeNode&& other) noexcept;

  // This matches the ID from the project model's processing graph node.
  Id id;

  // Keeps the source graph node alive while this runtime graph is active.
  //
  // Note that this cannot be accessed from real-time threads, since shared_ptr
  // is not real-time safe.
  std::shared_ptr<anthem::Node> sourceNode;

  // Higher values should be processed first when this node is ready.
  size_t priority = 0;

  // Number of unique nodes that must finish before this node can process.
  size_t upstreamNodeCount = 0;

  // Raw audio-thread-safe view into graph-owned buffers for this node.
  anthem::NodeProcessContext* nodeProcessContext = nullptr;

  // Raw pointer to the processor owned by the source node.
  anthem::Processor* processor = nullptr;

  // Mutable state that is reset for each processing block.
  RuntimeNodeState rt_state;

  // Connection-derived buffer operations that must run before this node
  // processes.
  std::vector<RuntimeConnectionTransferAction> connectionTransferActions;

  // Non-owning pointers to nodes owned by the RuntimeGraph.
  std::vector<RuntimeNode*> outgoingConnections;
};

} // namespace anthem
