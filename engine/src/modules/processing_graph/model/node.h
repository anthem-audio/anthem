/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include "generated/lib/model/processing_graph/node.h"

#include <optional>

class AnthemProcessContext;
class AnthemProcessor;

class Node : public NodeModelBase {
public:
  // This holds a pointer to the associated runtime context for this node, if
  // one exists. This is used to send live control updates to the audio thread,
  // via a vector of atomic floats.
  //
  // This doesn't risk a use-after-free as of this writing. The lifecycle of the
  // object in this pointer is as follows:
  //    1. When the graph is compiled, contexts are generated and owned by the
  //       compilation result object. The runtimeContext field of each
  //       AnthemGraphNode is also set during compilation.
  //    2. After compilation is finished, the resulting object is sent to the
  //       audio thread.
  //    3. If and when a new graph is compiled, this field is updated with a
  //       fresh context during the compilation and before the compiled result
  //       is sent to the audio thread.
  //    4. After the audio thread receives the new compilation result, it will
  //       send back the old compilation result for the main thread to
  //       deallocate.
  //
  // This field is always updated with a new pointer before the graph update is
  // sent to the audio thread, and the old pointer will not be freed until this
  // happens, so there is no risk of use-after-free.
  std::optional<AnthemProcessContext*> runtimeContext;

  Node(const NodeModelImpl& _impl) : NodeModelBase(_impl) {}
  ~Node() {}

  Node(const Node&) = delete;
  Node& operator=(const Node&) = delete;

  Node(Node&&) noexcept = default;
  Node& operator=(Node&&) noexcept = default;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    NodeModelBase::initialize(self, parent);
  }

  std::optional<std::shared_ptr<NodePort>> getPortById(int32_t id);

  std::optional<std::shared_ptr<AnthemProcessor>> getProcessor();
};
