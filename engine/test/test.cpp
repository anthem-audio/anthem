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

#include "console_logger.h"
#include "modules/core/sequencer_test.h"
#include "modules/processing_graph/compiler/actions/graph_compiler_actions_test.h"
#include "modules/processing_graph/compiler/graph_compiler_node_test.h"
#include "modules/processing_graph/compiler/graph_compiler_test.h"
#include "modules/processing_graph/compiler/graph_process_context_test.h"
#include "modules/processing_graph/compiler/node_process_context_test.h"
#include "modules/processing_graph/model/processing_graph_model_helpers_test.h"
#include "modules/processing_graph/processor/event_buffer_test.h"
#include "modules/processing_graph/runtime/graph_processor_test.h"
#include "modules/processors/balance_test.h"
#include "modules/processors/gain_parameter_mapping_test.h"
#include "modules/processors/gain_test.h"
#include "modules/processors/live_event_provider_test.h"
#include "modules/processors/sequence_note_provider_test.h"
#include "modules/sequencer/compiler/sequence_compiler_test.h"
#include "modules/sequencer/events/event_test.h"
#include "modules/sequencer/runtime/runtime_sequence_store_test.h"
#include "modules/sequencer/runtime/sequencer_timing_test.h"
#include "modules/sequencer/runtime/transport_test.h"

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>

int main(int /* argc */, char** /* argv */) {
  juce::ScopedJuceInitialiser_GUI juceInitialiser;
  juce::Logger::setCurrentLogger(new anthem::ConsoleLogger());

  juce::UnitTestRunner runner;
  runner.runAllTests();

  int resultCount = runner.getNumResults();
  int failureCount = 0;

  for (int i = 0; i < resultCount; i++) {
    auto result = runner.getResult(i);

    if (result->failures > 0) {
      failureCount++;
    }
  }

  juce::Logger::writeToLog("\n\n");
  if (failureCount > 0) {
    std::cerr << failureCount << " tests failed." << '\n';
    return 1;
  } else {
    juce::Logger::writeToLog("All tests passed.");
  }

  return 0;
}
