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

#include "process_node_action.h"

#include <iostream>

void ProcessNodeAction::execute(int numSamples) {
  this->node->processor->process(*this->context, numSamples);
}

void ProcessNodeAction::debugPrint() {
  std::cout << "ProcessNodeAction: " << this->node->processor->config.getName() << std::endl;
}
