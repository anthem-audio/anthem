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

#include "node.h"

#include "generated/lib/model/model.h"
#include "modules/processors/db_meter.h"

namespace anthem {

namespace {
std::optional<std::shared_ptr<NodePort>> getPortFromListById(
    ModelVector<std::shared_ptr<NodePort>>& ports, int64_t id) {
  for (auto& port : ports) {
    if (port->id() == id) {
      return port;
    }
  }

  return std::nullopt;
}
} // namespace

std::optional<std::shared_ptr<NodePort>> Node::getPortById(int64_t id) {
  for (auto& port : *this->audioInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->audioOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->controlInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->controlOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->eventInputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  for (auto& port : *this->eventOutputPorts()) {
    if (port->id() == id) {
      return port;
    }
  }

  return std::nullopt;
}

std::optional<std::shared_ptr<NodePort>> Node::getInputPortById(
    NodePortDataType dataType, int64_t id) {
  switch (dataType) {
    case NodePortDataType::audio:
      return getPortFromListById(*this->audioInputPorts(), id);
    case NodePortDataType::control:
      return getPortFromListById(*this->controlInputPorts(), id);
    case NodePortDataType::event:
      return getPortFromListById(*this->eventInputPorts(), id);
  }

  return std::nullopt;
}

std::optional<std::shared_ptr<NodePort>> Node::getOutputPortById(
    NodePortDataType dataType, int64_t id) {
  switch (dataType) {
    case NodePortDataType::audio:
      return getPortFromListById(*this->audioOutputPorts(), id);
    case NodePortDataType::control:
      return getPortFromListById(*this->controlOutputPorts(), id);
    case NodePortDataType::event:
      return getPortFromListById(*this->eventOutputPorts(), id);
  }

  return std::nullopt;
}

std::optional<std::shared_ptr<Processor>> Node::getProcessor() {
  auto& processor = this->processor();

  if (!processor.has_value()) {
    return std::nullopt;
  }

  return rfl::visit(
      [](auto const& field) -> std::shared_ptr<Processor> {
        // field is of type rfl::Field<Name, T>
        using FieldType = std::decay_t<decltype(field)>;
        // T is the second template parameter of rfl::Field
        using PtrType = typename FieldType::Type;
        // e.g. std::shared_ptr<ToneGeneratorProcessor>

        // Check that all stored types truly derive from AnthemProcessor:
        static_assert(std::is_base_of_v<Processor, typename PtrType::element_type>,
            "All types must derive from AnthemProcessor. This means that all processors "
            "need a user-defined implementation class that inherits from "
            "AnthemProcessor. See master_output.h for an example.");

        return std::static_pointer_cast<Processor>(field.value());
      },
      *processor);
}

} // namespace anthem
