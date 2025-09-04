/*
  Copyright (C) 2025 Joshua Wade

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

#include <iostream>

#define JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED 1

#include "../include/juce_core_wasm.h"
#include "../include/juce_audio_basics_wasm.h"
#include "../include/juce_events_wasm.h"

int main() {
  std::cout << "Hello world from Anthem engine!" << std::endl;

  
  std::cout << "--- juce_core ---------------" << std::endl;
  std::cout << "Min of 3 and 4, from JUCE: " << juce::jmin(3, 4) << std::endl;

  std::cout << "--- juce_audio_basics -------" << std::endl;
  juce::AudioSampleBuffer buffer;
  buffer.setSize(2, 512);
  buffer.clear();
  std::cout << "Buffer size: " << buffer.getNumChannels() << "x" << buffer.getNumSamples() << std::endl;

  std::cout << "--- juce_events -------------" << std::endl;
  juce::NotificationType notificationType = juce::NotificationType::sendNotification;
  std::cout << "Notification type from juce_events available - " << notificationType << std::endl;

  std::cout << "--- pthreads ----------------" << std::endl;
  #ifdef __EMSCRIPTEN_PTHREADS__
  std::cout << "Running with Emscripten pthreads enabled." << std::endl;
  #endif
}
