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

#include "processor/anthem_processor.h"
#include "compiler/anthem_graph_compiler.h"
#include "runtime/anthem_graph_processor.h"

// This class is used to store processors and their connections, and to manage
// the flow of audio, MIDI and control data between them.
//
// TODO: Unify with the processing graph in the model
class AnthemGraph {
private:
  // The compiler, which takes the topology from the model and converts it into
  // processing steps
  std::unique_ptr<AnthemGraphCompiler> compiler;

  // The processor, which takes the compilation result from the compiler and
  // uses it on the audio thread to process data in the graph
  std::unique_ptr<AnthemGraphProcessor> graphProcessor;

  // This method is called when the graph is updated, and it updates the
  // graph processor.
  void sendCompiledGraphToProcessor(AnthemGraphCompilationResult* compiledGraph);
public:
  AnthemGraph();

  AnthemGraphProcessor& getProcessor() {
    return *graphProcessor;
  }

  // Compiles the topology, and pushes the result to the audio thread
  void compile();
};
