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

#include <juce_core/juce_core.h>

#include "console_logger.h"

#include "modules/sequencer/compiler/sequence_compiler_test.h"
#include "modules/sequencer/events/event_test.h"
#include "modules/sequencer/runtime/runtime_sequence_store_test.h"
#include "modules/util/arena_allocator_test.h"

int main(int argc, char** argv) {
  juce::Logger::setCurrentLogger(new ConsoleLogger());

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
    juce::Logger::writeToLog(juce::String(failureCount) + " tests failed.");
  } else {
    juce::Logger::writeToLog("All tests passed.");
  }

  return 0;
}
