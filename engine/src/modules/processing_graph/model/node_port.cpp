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

#include "generated/lib/model/model.h"

#include "modules/processing_graph/compiler/anthem_process_context.h"

void NodePort::initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
  NodePortModelBase::initialize(self, parent);

  if (this->config()->parameterConfig().has_value()) {
    this->addParameterValueObserver([this](std::optional<double> value) {
      if (value.has_value()) {
        std::cout << "NodePort parameter value changed: " << std::to_string(value.value()) << std::endl;
      } else {
        std::cout << "NodePort parameter value changed: null" << std::endl;
        return;
      }

      std::shared_ptr<AnthemModelBase> collectionParent = this->parent.lock();
      
      if (!collectionParent) {
        return;
      }

      std::shared_ptr<AnthemModelBase> nodeAsBase = collectionParent->parent.lock();

      if (!nodeAsBase) {
        return;
      }

      std::shared_ptr<Node> node = std::dynamic_pointer_cast<Node>(nodeAsBase);

      if (!node) {
        return;
      }

      if (!node->runtimeContext.has_value()) {
        return;
      }

      node->runtimeContext.value()->setParameterValue(this->id(), value.value());
    });
  }

  std::cout << "NodePort initialized" << std::endl;
}
