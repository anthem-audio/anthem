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

#include <iostream>
#include <juce_core/juce_core.h>
#include <memory>

namespace anthem {

class ConsoleLogger : public juce::Logger {
public:
  void logMessage(const juce::String& message) override {
    std::cout << message << std::endl;
  }
};

class TeeLogger : public juce::Logger {
private:
  std::unique_ptr<juce::FileLogger> fileLogger;
  std::unique_ptr<ConsoleLogger> consoleLogger;

public:
  TeeLogger(std::unique_ptr<juce::FileLogger> fileLogger,
      std::unique_ptr<ConsoleLogger> consoleLogger)
      : fileLogger(std::move(fileLogger)), consoleLogger(std::move(consoleLogger)) {}

  void logMessage(const juce::String& message) override {
    if (fileLogger != nullptr) {
      fileLogger->logMessage(message);
    }

    if (consoleLogger != nullptr) {
      consoleLogger->logMessage(message);
    }
  }
};

} // namespace anthem
