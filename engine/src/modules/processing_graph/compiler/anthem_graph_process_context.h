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

#include <memory>
#include <vector>
#include <cstddef>

#include <juce_core/juce_core.h>
#include <juce_audio_basics/juce_audio_basics.h>

#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/sequencer/events/note_instance_id.h"

class Node;
class GraphRuntimeServices;
class AnthemNodeProcessContext;

// Owns all graph-scoped runtime storage that is compiled alongside a live
// processing graph result.
//
// This is the storage owner for a compiled graph's contiguous runtime state.
// Node contexts are created through this class and act as lightweight views
// into the buffers and services owned here.
class AnthemGraphProcessContext {
private:
  JUCE_LEAK_DETECTOR(AnthemGraphProcessContext)

  // Long-lived runtime services that are shared across compiled graphs and
  // must remain stable across graph recompilation.
  GraphRuntimeServices* rt_services = nullptr;

  // The current device layout used when allocating audio and control buffers.
  int numAudioChannels = 0;
  int blockSize = 0;

  // Backing storage for graph-owned per-port buffers.
  std::vector<juce::AudioSampleBuffer> audioBuffers;
  std::vector<juce::AudioSampleBuffer> controlBuffers;
  std::vector<std::unique_ptr<AnthemEventBuffer>> eventBuffers;

  // Owns all node-scoped views into the graph-owned runtime storage above.
  std::vector<std::unique_ptr<AnthemNodeProcessContext>> nodeProcessContexts;
public:
  // Initializes a graph context using the current audio device configuration.
  explicit AnthemGraphProcessContext(GraphRuntimeServices& rtServices);
  ~AnthemGraphProcessContext();

  // Reserves capacity for all graph-owned runtime objects before node contexts
  // are created. This keeps the backing arrays stable while compilation builds
  // buffer bindings into node contexts.
  void reserve(
    size_t nodeProcessContextCount,
    size_t audioBufferCount,
    size_t controlBufferCount,
    size_t eventBufferCount
  );

  // Appends a new graph-owned buffer and returns its stable index.
  size_t allocateAudioBuffer();
  size_t allocateControlBuffer();
  size_t allocateEventBuffer(size_t initialCapacity);

  // Creates a node-scoped view into this graph-owned storage.
  AnthemNodeProcessContext& createNodeProcessContext(std::shared_ptr<Node>& graphNode);

  // Access graph-owned buffers by the indices stored in node contexts.
  juce::AudioSampleBuffer& getAudioBuffer(size_t index);
  juce::AudioSampleBuffer& getControlBuffer(size_t index);
  std::unique_ptr<AnthemEventBuffer>& getEventBuffer(size_t index);

  // Allocates a live note ID using the shared runtime service layer.
  AnthemLiveNoteId rt_allocateLiveNoteId();

  // Gives owned node contexts a chance to release any non-RAII runtime state
  // before this graph context is destroyed.
  void cleanup();
};
