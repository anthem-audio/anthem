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

#include "anthem_process_context.h"
#include "anthem_graph_node.h"
#include "anthem_graph_compiler_action.h"

class ProcessNodeAction : public AnthemGraphCompilerAction {
public:
  std::shared_ptr<AnthemProcessContext> context;
  std::shared_ptr<AnthemGraphNode> node;

  void execute() override;

  ProcessNodeAction(std::shared_ptr<AnthemProcessContext> context, std::shared_ptr<AnthemGraphNode> node) : context(context), node(node) {}
};
