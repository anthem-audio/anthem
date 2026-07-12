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

#include "modules/processing_graph/processor/event_buffer.h"
#include "modules/processing_graph/runtime/audio_buffer_slot_slice.h"
#include "modules/processing_graph/runtime/audio_buffer_view.h"
#include "modules/processing_graph/runtime/node_process_context.h"
#include "modules/sequencer/events/note_instance_id.h"
#include "modules/util/arena_allocator.h"

#include <cstddef>
#include <cstdint>
#include <juce_core/juce_core.h>
#include <memory>
#include <optional>
#include <vector>

namespace anthem {

class Node;
class EngineRuntimeServices;
class RuntimeGraph;

struct GraphBufferLayout {
  int numAudioChannels = 0;
  int blockSize = 0;
};

// Owns all graph-scoped runtime storage that is prepared alongside a live
// processing graph result.
//
// This is the storage owner for a published graph's contiguous runtime state.
// Node contexts are created through this class and act as lightweight views
// into the buffers owned here and the engine-level services referenced here.
class GraphProcessContext {
public:
  // Scoped graph-publishing interface. Runtime code can keep and use a
  // GraphProcessContext without being able to mutate its storage layout.
  class Builder {
  public:
    Builder(const Builder&) = delete;
    Builder& operator=(const Builder&) = delete;

    Builder(Builder&&) noexcept = default;
    Builder& operator=(Builder&&) noexcept = default;

    void reserve(size_t nodeProcessContextCount,
        size_t audioBufferCount,
        size_t controlBufferCount,
        size_t eventBufferCount);

    size_t declareAudioBufferSlot();
    size_t declareAudioBufferSlot(int channelCount);
    size_t allocateControlBuffer();
    size_t allocateEventBuffer(size_t initialCapacity);
    size_t getSharedEmptyEventBufferIndex();

    NodeProcessContext& createNodeProcessContext(
        std::shared_ptr<Node>& graphNode, NodeProcessContext::BufferBindings bufferBindings);

    void registerSampleBufferSlotsUsedByNode(const std::vector<size_t>& slotIndices);
    void setSampleBufferSlotClearOnAllocate(size_t index, bool clearOnAllocate);
    void finalizeSampleArena();
  private:
    friend class RuntimeGraph;
    friend class BalanceProcessorTest;
    friend class GainProcessorTest;
    friend class GraphProcessContextTest;
    friend class LiveEventProviderProcessorTest;
    friend class NodeProcessContextTest;
    friend class ProcessingGraphModelHelpersTest;
    friend class UtilityProcessorTest;

    explicit Builder(GraphProcessContext& context) : context(&context) {}

    GraphProcessContext* context = nullptr;
  };
private:
  JUCE_LEAK_DETECTOR(GraphProcessContext)

  // App-level real-time services shared across published graphs.
  EngineRuntimeServices* rt_engineRuntimeServices = nullptr;

  // The current device layout used when allocating audio and control buffers.
  int numAudioChannels = 0;
  int blockSize = 0;

  enum class SampleBufferSlotKind : uint8_t {
    audio,
    control,
  };

  struct SampleBufferSlot {
    SampleBufferSlotKind kind = SampleBufferSlotKind::audio;
    int channelCount = 0;
    bool clearOnAllocate = true;
    std::optional<ArenaAllocator::Handle> rt_arenaHandle;
    size_t nodeUseCount = 0;
    size_t rt_remainingNodeUseCount = 0;
  };

  // Logical graph-owned sample buffers. Audio buffers use one arena block per
  // channel; control buffers are one-channel sample buffers in the same arena.
  std::vector<SampleBufferSlot> sampleBufferSlots;
  std::unique_ptr<ArenaAllocator> sampleArena;

  // Event buffers remain statically allocated for now.
  std::vector<std::unique_ptr<EventBuffer>> eventBuffers;

  std::optional<size_t> sharedEmptyEventBufferIndex;

  // Owns all node-scoped views into the graph-owned runtime storage above.
  std::vector<std::unique_ptr<NodeProcessContext>> nodeProcessContexts;
public:
  explicit GraphProcessContext(
      EngineRuntimeServices& rtServices, const GraphBufferLayout& bufferLayout);
  ~GraphProcessContext();

  int getDefaultAudioChannelCount() const;
  int getBlockSize() const;
  size_t getSampleBufferSlotCount() const;
  int getSampleBufferSlotChannelCount(size_t index) const;
  bool getSampleBufferSlotClearOnAllocate(size_t index) const;

  // Audio-thread operations used by the graph executor. Sample slot allocation
  // and release must be serialized by the executor.
  void rt_prepareSampleArenaForBlock();
  void rt_allocateSampleBufferSlotsForNode(const std::vector<size_t>& slotIndices);
  // Decrements this node's slot-use counts and frees only slots whose final
  // remaining use was released.
  void rt_releaseSampleBufferSlotUsesForNode(const std::vector<size_t>& slotIndices);
  void rt_allocateAllSampleBufferSlots();
  AudioBufferView rt_getAudioBufferView(size_t index);
  AudioBufferView rt_getAudioBufferView(const AudioBufferSlotSlice& slice);
  AudioBufferView rt_getControlBufferView(size_t index);

  // Access graph-owned static event buffers by the indices stored in node
  // contexts.
  std::unique_ptr<EventBuffer>& getEventBuffer(size_t index);

  // Allocates a live note ID using the shared runtime service layer.
  LiveNoteId rt_allocateLiveNoteId();

  EngineRuntimeServices& rt_getEngineRuntimeServices();

  // Gives owned node contexts a chance to release any non-RAII runtime state
  // before this graph context is destroyed.
  void cleanup();
};

} // namespace anthem
