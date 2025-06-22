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

#include "copy_events_action.h"

void CopyEventsAction::execute([[maybe_unused]] int numSamples) {
  auto& sourceBuffer = this->source->getOutputEventBuffer(this->sourcePortId);
  auto& destinationBuffer = this->destination->getInputEventBuffer(this->destinationPortId);

  // Ensure the buffers have the same size
  jassert(sourceBuffer->getNumEvents() == destinationBuffer->getNumEvents());

  for (int event = 0; event < sourceBuffer->getNumEvents(); ++event) {
    // Copy the event from the source buffer to the destination buffer
    destinationBuffer->addEvent(sourceBuffer->getEvent(event));
  }
}

void CopyEventsAction::debugPrint() {
  std::cout 
    << "CopyEventsAction: "
    << this->source->getGraphNode()->id()
    << " -> "
    << this->destination->getGraphNode()->id()
    << std::endl;
}
