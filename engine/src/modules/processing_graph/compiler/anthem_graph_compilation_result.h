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
