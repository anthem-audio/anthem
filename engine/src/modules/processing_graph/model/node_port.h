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

#include "generated/lib/model/processing_graph/node_port.h"

class NodePort : public NodePortModelBase {
public:
  NodePort(const NodePortModelImpl& _impl) : NodePortModelBase(_impl) {std::cout << "NodePort created" << std::endl;}
  ~NodePort() {}

  NodePort(const NodePort&) = delete;
  NodePort& operator=(const NodePort&) = delete;

  NodePort(NodePort&&) noexcept = default;
  NodePort& operator=(NodePort&&) = default;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override;
};
