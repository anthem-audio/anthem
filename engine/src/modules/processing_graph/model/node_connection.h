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

#include "generated/lib/model/processing_graph/node_connection.h"

class NodeConnection : public NodeConnectionModelBase {
public:
  NodeConnection(const NodeConnectionModelImpl& _impl) : NodeConnectionModelBase(_impl) {std::cout << "NodeConnection created" << std::endl;}
  ~NodeConnection() {}

  NodeConnection(const NodeConnection&) = delete;
  NodeConnection& operator=(const NodeConnection&) = delete;

  NodeConnection(NodeConnection&&) noexcept = default;
  NodeConnection& operator=(NodeConnection&&) noexcept = default;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    std::cout << "NODE CONNECTION INITIALIZE" << std::endl;
  }
};
