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

#include "node_port.h"

void NodePort::initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
  NodePortModelBase::initialize(self, parent);

  this->addParameterValueObserver([this](std::optional<double> value) {
    if (value.has_value()) {
      std::cout << "NodePort parameter value changed: " << std::to_string(value.value()) << std::endl;
    } else {
      std::cout << "NodePort parameter value changed: null" << std::endl;
    }
  });

  std::cout << "NodePort initialized" << std::endl;
}
