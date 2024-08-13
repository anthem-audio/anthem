/*
  Copyright (C) 2024 Joshua Wade

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
#include <iostream>

#include "anthem_graph_compiler_action.h"
#include "anthem_process_context.h"
#include "anthem_graph_node.h"

// This class is used to represent the result of compiling a processing graph.
class AnthemGraphCompilationResult {
public:
  // All actions in a given group can be executed in parallel.
  // 
  // The way these groups are constructed currently is quite naive and no work
  // has been done to optimize it.
  std::vector<
    std::unique_ptr<
      std::vector<
        std::unique_ptr<AnthemGraphCompilerAction>
      >
    >
  > actionGroups;

  // This contains all process contexts. These are used in a number of different
  // actions, and are (among other things) provided to processors when process()
  // is called. Since there is no obvious owner, these are owned by the root
  // compilation result, because they become invalid and must be deallocated
  // when the compilation result is deallocated.
  //
  // This would be a great use-case for std::shared_ptr, but std::shared_ptr
  // uses standard thread synchronization mechanisms and so isn't real-time
  // safe.
  std::vector<
    std::unique_ptr<
      AnthemProcessContext
    >
  > processContexts;

  // This contains a shared_ptr reference to each graph node that was present
  // when this context was created.
  //
  // This exists to ensure that graph nodes are not freed until the audio thread
  // is done with them. The audio thread itself can't interact with these since
  // they aren't thread-safe; instead, the deallocation of the compilation
  // result on the main thread triggers deallocation for any nodes that need it.
  //
  // Note that the audio thread only has access to these nodes so that it can
  // call node->processor->process(&context, numSamples).
  //
  // If this list didn't exist, then we'd risk the following use-after-free:
  //    1. A node is created and connected to the rest of the graph.
  //    2. The graph is compiled, and the result is sent to the audio thread.
  //    3. The node is removed from the audio graph, with a compiled update
  //       expected to be sent next.
  //    4. Before the compiled update can be sent, this node is deallocated
  //       because it has no more shared_ptr references.
  //    5. The audio thread continues to use its raw pointer to try to access
  //       the node, which results in a use-after-free.
  std::vector<
    std::shared_ptr<
      AnthemGraphNode
    >
  > graphNodes;

  // This is the allocator for the event buffer. This allocator maintains a huge
  // buffer of memory that can be used to reallocate node event buffers if they
  // become saturated, without having to allocate from the OS. This allows the
  // audio processing code to support effectively unlimited numbers of events
  // without any real-time safety concerns, except in extreme edge cases.
  //
  // This buffer is owned here, and is handed out to the event buffers that need
  // it. When this class is deallocated, the buffer is deallocated.
  std::unique_ptr<
    ArenaBufferAllocator<
      AnthemProcessorEvent
    >
  > eventAllocator;

  void debugPrint() {
    std::cout << "AnthemGraphCompilationResult" << std::endl;
    std::cout << actionGroups.size() << " action groups" << std::endl;
    for (auto& group : actionGroups) {
      std::cout << "  ActionGroup" << std::endl << "  ";
      for (auto& action : *group) {
        action->debugPrint();
      }
    }
  }
};
