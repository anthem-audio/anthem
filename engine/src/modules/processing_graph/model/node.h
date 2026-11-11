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

#pragma once

#include "generated/lib/model/processing_graph/node.h"
#include "modules/processing_graph/model/node_port.h"
#include "modules/processors/balance.h"
#include "modules/processors/control_value_visualization.h"
#include "modules/processors/db_meter.h"
#include "modules/processors/gain.h"
#include "modules/processors/live_event_provider.h"
#include "modules/processors/master_output.h"
#include "modules/processors/sequence_automation_provider.h"
#include "modules/processors/sequence_note_provider.h"
#include "modules/processors/simple_midi_generator.h"
#include "modules/processors/simple_volume_lfo.h"
#include "modules/processors/tone_generator.h"
#include "modules/processors/utility.h"
#include "modules/processors/vst3_processor.h"

#include <cstdint>
#include <optional>
#include <vector>

namespace anthem {

class NodeProcessContext;
class Processor;

class Node : public NodeModelBase {
public:
  Node(const NodeModelImpl& _impl) : NodeModelBase(_impl) {}
  ~Node() {}

  Node(const Node&) = delete;
  Node& operator=(const Node&) = delete;

  Node(Node&&) noexcept = default;
  Node& operator=(Node&&) noexcept = default;

  void initialize(
      std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) override {
    NodeModelBase::initialize(selfModel, parentModel);
  }

  // Cached available ports, rebuilt at the start of runtime graph compilation.
  void refreshAvailablePorts();
  const std::vector<std::shared_ptr<NodePort>>& availableAudioInputPorts() const {
    return audioInputAvailable;
  }
  const std::vector<std::shared_ptr<NodePort>>& availableAudioOutputPorts() const {
    return audioOutputAvailable;
  }
  const std::vector<std::shared_ptr<NodePort>>& availableControlInputPorts() const {
    return controlInputAvailable;
  }
  const std::vector<std::shared_ptr<NodePort>>& availableControlOutputPorts() const {
    return controlOutputAvailable;
  }
  const std::vector<std::shared_ptr<NodePort>>& availableEventInputPorts() const {
    return eventInputAvailable;
  }
  const std::vector<std::shared_ptr<NodePort>>& availableEventOutputPorts() const {
    return eventOutputAvailable;
  }

  std::optional<std::shared_ptr<NodePort>> getPortById(int64_t id);
  std::optional<std::shared_ptr<NodePort>> getInputPortById(NodePortDataType dataType, int64_t id);
  std::optional<std::shared_ptr<NodePort>> getOutputPortById(NodePortDataType dataType, int64_t id);

  std::shared_ptr<Processor> getProcessor();
private:
  std::vector<std::shared_ptr<NodePort>> audioInputAvailable;
  std::vector<std::shared_ptr<NodePort>> audioOutputAvailable;
  std::vector<std::shared_ptr<NodePort>> controlInputAvailable;
  std::vector<std::shared_ptr<NodePort>> controlOutputAvailable;
  std::vector<std::shared_ptr<NodePort>> eventInputAvailable;
  std::vector<std::shared_ptr<NodePort>> eventOutputAvailable;
};

} // namespace anthem
