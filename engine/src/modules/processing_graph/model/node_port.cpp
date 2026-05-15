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

#include "node_port.h"

#include "generated/lib/model/model.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <juce_core/juce_core.h>

namespace anthem {

void NodePort::initialize(
    std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) {
  NodePortModelBase::initialize(selfModel, parentModel);

  if (this->config()->parameterConfig().has_value()) {
    this->addParameterValueObserver([this](std::optional<double> value) {
      if (!value.has_value()) {
        return;
      }

      this->sendParameterValueToAudioThreadIfBound(value.value());
    });

    std::optional<double> value = this->parameterValue();

    if (value.has_value()) {
      this->sendParameterValueToAudioThreadIfBound(value.value());
    }
  }
}

void NodePort::sendParameterValueToAudioThreadIfBound(double value) {
  jassert(juce::jlimit(0.0, 1.0, value) == value);

  std::shared_ptr<ModelBase> collectionParent = this->parent.lock();

  if (!collectionParent) {
    return;
  }

  std::shared_ptr<ModelBase> nodeAsBase = collectionParent->parent.lock();

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

  node->runtimeContext.value()->setParameterValue(this->id(), static_cast<float>(value));
}

} // namespace anthem
