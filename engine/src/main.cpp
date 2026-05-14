/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

// #define JUCE_CHECK_MEMORY_LEAKS 0

#include "modules/core/engine.h"

#include "console_logger.h"

#include <juce_audio_devices/juce_audio_devices.h>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>

#ifdef __EMSCRIPTEN__
#include "modules/core/comms_methods_for_ui_wasm.h"
#endif

namespace anthem {

class EngineApplication : public juce::JUCEApplicationBase, private juce::ChangeListener {
private:
  std::unique_ptr<juce::Logger> logger;

  void changeListenerCallback(juce::ChangeBroadcaster* /*source*/) override {
    // juce::Logger::writeToLog("change detected");
  }

  void initializeLogging() {
#ifdef __EMSCRIPTEN__
    logger = std::make_unique<ConsoleLogger>();
    juce::Logger::setCurrentLogger(logger.get());
#else
    auto fileLogger = std::unique_ptr<juce::FileLogger>(juce::FileLogger::createDefaultAppLogger(
        "Anthem", "AnthemEngine.log", "Anthem Engine", static_cast<juce::int64>(1024) * 1024));

    if (fileLogger == nullptr) {
      juce::Logger::writeToLog("Failed to create Anthem engine file logger.");
      return;
    }

    const auto logFilePath = fileLogger->getLogFile().getFullPathName();
#if !defined(NDEBUG)
    logger = std::make_unique<ConsoleLogger>();
#else
    logger = std::move(fileLogger);
#endif
    juce::Logger::setCurrentLogger(logger.get());

    juce::Logger::writeToLog(juce::String("Logging to ") + logFilePath);
#endif
  }
public:
  EngineApplication() {}

  const juce::String getApplicationName() override {
    return "JUCE_APPLICATION_NAME_STRING";
  }
  const juce::String getApplicationVersion() override {
    return "0.0.1";
  }

  bool moreThanOneInstanceAllowed() override {
    return true;
  }

  void anotherInstanceStarted(const juce::String& /*commandLineParameters*/) override {}
  void suspended() override {}
  void resumed() override {}
  void shutdown() override {
    juce::Logger::writeToLog("Shutting down Anthem engine...");

    // Destruct Anthem instance
    if (Engine::hasInstance()) {
      Engine::getInstance().shutdown();
      Engine::cleanup();
    }

    juce::Logger::setCurrentLogger(nullptr);
    logger.reset();
  }

  void systemRequestedQuit() override {
    setApplicationReturnValue(0);
    quit();
  }

  void unhandledException(const std::exception* /*exception*/,
      const juce::String& /*sourceFilename*/,
      int /*lineNumber*/) override {
    // This might not work
  }

  void initialise(const juce::String& /*commandLineParameters*/) override {
    initializeLogging();

    // wow, C++ sure is weird
    const char* anthemSplash = R"V0G0N(
           ,++,
          /####\
         /##**##\
        =##/  \##=              ,---.            ,--.  ,--.                       
      /##=/    \=##\           /  O  \ ,--,--, ,-'  '-.|  ,---.  ,---. ,--,--,--. 
     =##/   ..   \##=         |  .-.  ||      \'-.  .-'|  .-.  || .-. :|        | 
   /##=/   /##\   \=##\       |  | |  ||  ||  |  |  |  |  | |  |\   --.|  |  |  | 
  =##,    /####\    ,##=      `--' `--'`--''--'  `--'  `--' `--' `----'`--`--`--' 
.#####---*##/\##*---#####.
 *=#######*/  \*#######=*



)V0G0N";

    juce::Logger::writeToLog(anthemSplash);

    // juce::Logger::writeToLog("If you want to attach a debugger, you can do it now. Press enter to continue.");
    // std::cin.get();

    juce::Logger::writeToLog("Starting Anthem engine...");

    Engine::getInstance().initialize();
  }
};

} // namespace anthem

START_JUCE_APPLICATION(anthem::EngineApplication);
