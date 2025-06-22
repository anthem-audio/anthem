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

#include "node.h"
#include "generated/lib/model/model.h"

std::optional<std::shared_ptr<NodePort>> Node::getPortById(int32_t id) {
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

std::optional<std::shared_ptr<AnthemProcessor>> Node::getProcessor() {
  if (!this->processor().has_value()) {
    return std::nullopt;
  }

  return rfl::visit(
    [](auto const& field) -> std::shared_ptr<AnthemProcessor> {
      // field is of type rfl::Field<Name, T>
      using FieldType = std::decay_t<decltype(field)>;
      // T is the second template parameter of rfl::Field
      using PtrType = typename FieldType::Type; 
      // e.g. std::shared_ptr<ToneGeneratorProcessor>

      // Check that all stored types truly derive from AnthemProcessor:
      static_assert(
          std::is_base_of_v<AnthemProcessor, typename PtrType::element_type>,
          "All types must derive from AnthemProcessor. This means that all processors need a user-defined implementation class that inherits from AnthemProcessor. See master_output.h for an example."
      );
      
      return std::static_pointer_cast<AnthemProcessor>(field.value());
    },
    this->processor().value()
  );
}
