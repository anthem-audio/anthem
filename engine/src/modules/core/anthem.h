/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

#include <memory>
#include <iostream>

#include <juce_audio_devices/juce_audio_devices.h>

#include "modules/core/anthem_audio_callback.h"
#include "modules/processing_graph/runtime/anthem_graph_processor.h"
#include "modules/processing_graph/compiler/anthem_graph_compiler.h"

#include "modules/util/id_generator.h"

#include "project.h"

class Anthem {
private:
  bool isAudioCallbackRunning;

  // Singleton shared pointer instance
  static std::shared_ptr<Anthem> instance;

  juce::AudioDeviceManager deviceManager;

  std::unique_ptr<AnthemAudioCallback> audioCallback;

  // Sets up the audio callback
  void startAudioCallback();
public:
  // The project model.
  //
  // This is mostly code-generated, and is based on the project model defined in
  // Dart. It is automatically synced with the Dart model, and is used to store
  // the state of the project.
  std::shared_ptr<Project> project;

  // The graph compiler, which turns the graph topology from the model into
  // processing steps
  std::unique_ptr<AnthemGraphCompiler> compiler;

  // The graph processor, which takes the compilation result from the compiler
  // and uses it on the audio thread to process data in the graph
  std::unique_ptr<AnthemGraphProcessor> graphProcessor;

  Anthem();

  // Singleton instance getter
  static std::shared_ptr<Anthem> getInstancePtr() {
    if (!instance) {
      instance = std::make_shared<Anthem>();
    }
    return instance;
  }

  // Singleton instance getter
  static Anthem& getInstance() {
    if (!instance) {
      instance = std::make_shared<Anthem>();
    }
    return *instance;
  }

  void compileProcessingGraph();

  // TODO: These generic config items should be settable, which means they
  // should live in the actual synced model.
  static const int SAMPLE_RATE = 44100;
  static const int NUM_CHANNELS = 2;
};
