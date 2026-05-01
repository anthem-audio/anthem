/*
  Copyright (C) 2026 Joshua Wade

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

#include "runtime_node.h"

#include <utility>

namespace anthem {

RuntimeNodeState::RuntimeNodeState(RuntimeNodeState&& other) noexcept {
  rt_remainingUpstreamNodes.store(
      other.rt_remainingUpstreamNodes.load(std::memory_order_relaxed), std::memory_order_relaxed);
}

RuntimeNodeState& RuntimeNodeState::operator=(RuntimeNodeState&& other) noexcept {
  if (this != &other) {
    rt_remainingUpstreamNodes.store(
        other.rt_remainingUpstreamNodes.load(std::memory_order_relaxed), std::memory_order_relaxed);
  }

  return *this;
}

RuntimeNode::RuntimeNode(Id id, std::shared_ptr<anthem::Node> sourceNode)
  : id(id), sourceNode(std::move(sourceNode)) {}

RuntimeNode::RuntimeNode(RuntimeNode&& other) noexcept
  : id(other.id), sourceNode(std::move(other.sourceNode)), priority(other.priority),
    upstreamNodeCount(other.upstreamNodeCount), nodeProcessContext(other.nodeProcessContext),
    processor(other.processor), rt_state(std::move(other.rt_state)),
    incomingConnectionCopies(std::move(other.incomingConnectionCopies)),
    outgoingConnections(std::move(other.outgoingConnections)) {}

RuntimeNode& RuntimeNode::operator=(RuntimeNode&& other) noexcept {
  if (this != &other) {
    id = other.id;
    sourceNode = std::move(other.sourceNode);
    priority = other.priority;
    upstreamNodeCount = other.upstreamNodeCount;
    nodeProcessContext = other.nodeProcessContext;
    processor = other.processor;
    rt_state = std::move(other.rt_state);
    incomingConnectionCopies = std::move(other.incomingConnectionCopies);
    outgoingConnections = std::move(other.outgoingConnections);
  }

  return *this;
}

} // namespace anthem
