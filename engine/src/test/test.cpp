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

#include <juce_core/juce_core.h>

#include "console_logger.h"



int main(int argc, char** argv) {
  juce::Logger::setCurrentLogger(new ConsoleLogger());

  juce::UnitTestRunner runner;
  runner.runAllTests();

  for (int i = 0; i < runner.getNumResults(); i++) {
    auto result = runner.getResult(i);
    
    if (result->failures > 0) {
      return 1;
    }
  }

  return 0;
}
