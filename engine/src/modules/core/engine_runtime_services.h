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

#pragma once

#include "modules/processing_graph/runtime/live_note_id_generator.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <juce_core/juce_core.h>

namespace anthem {

class Transport;

class EngineRuntimeServices {
public:
  EngineRuntimeServices() = default;

  EngineRuntimeServices(Transport& transport,
      RuntimeSequenceStore& sequenceStore,
      RuntimeAutomationSequenceStore& automationSequenceStore) {
    bind(transport, sequenceStore, automationSequenceStore);
  }

  void bind(Transport& transport,
      RuntimeSequenceStore& sequenceStore,
      RuntimeAutomationSequenceStore& automationSequenceStore) {
    rt_transport = &transport;
    rt_sequenceStore = &sequenceStore;
    rt_automationSequenceStore = &automationSequenceStore;
  }

  Transport& rt_getTransport() const {
    jassert(rt_transport != nullptr);
    return *rt_transport;
  }

  RuntimeSequenceStore& rt_getSequenceStore() const {
    jassert(rt_sequenceStore != nullptr);
    return *rt_sequenceStore;
  }

  RuntimeAutomationSequenceStore& rt_getAutomationSequenceStore() const {
    jassert(rt_automationSequenceStore != nullptr);
    return *rt_automationSequenceStore;
  }

  LiveNoteId rt_allocateLiveNoteId() {
    return rt_liveNoteIdGenerator.rt_allocate();
  }

  void rt_reset() {
    rt_liveNoteIdGenerator.reset();
  }
private:
  Transport* rt_transport = nullptr;
  RuntimeSequenceStore* rt_sequenceStore = nullptr;
  RuntimeAutomationSequenceStore* rt_automationSequenceStore = nullptr;
  LiveNoteIdGenerator rt_liveNoteIdGenerator;
};

} // namespace anthem
