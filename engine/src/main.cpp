/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

#include <juce_events/juce_events.h>
#include <juce_core/juce_core.h>
#include <juce_audio_devices/juce_audio_devices.h>

#include <iostream>

#include "console_logger.h"

#include "modules/core/anthem.h"

class AnthemEngineApplication : public juce::JUCEApplicationBase, private juce::ChangeListener
{
private:
  void changeListenerCallback(juce::ChangeBroadcaster */*source*/) override
  {
    // juce::Logger::writeToLog("change detected");
  }

public:
  AnthemEngineApplication() {}

  const juce::String getApplicationName() override { return "JUCE_APPLICATION_NAME_STRING"; }
  const juce::String getApplicationVersion() override { return "0.0.1"; }

  bool moreThanOneInstanceAllowed() override { return true; }

  void anotherInstanceStarted(const juce::String &/*commandLineParameters*/) override {}
  void suspended() override {}
  void resumed() override {}
  void shutdown() override {
    // Destruct Anthem instance
    if (Anthem::hasInstance()) {
      Anthem::getInstance().shutdown();
      Anthem::cleanup();
    }
  }

  void systemRequestedQuit() override
  {
    setApplicationReturnValue(0);
    quit();
  }

  void unhandledException(const std::exception */*exception*/, const juce::String &/*sourceFilename*/,
              int /*lineNumber*/) override
  {
    // This might not work
  }

  void initialise(const juce::String &commandLineParameters) override
  {
    // Remove this line to disable logging
    juce::Logger::setCurrentLogger(new ConsoleLogger());

                                // wow, C++ sure is weird
    const char * anthemSplash = R"V0G0N(
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

    std::cout << anthemSplash;

    // juce::Logger::writeToLog("If you want to attach a debugger, you can do it now. Press enter to continue.");
    // std::cin.get();

    juce::Logger::writeToLog("Starting Anthem engine...");
    
    Anthem::getInstance().initialize();
  }
};

START_JUCE_APPLICATION(AnthemEngineApplication);
