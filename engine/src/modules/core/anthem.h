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

#pragma once

#include <memory>
#include <iostream>

#include <juce_audio_devices/juce_audio_devices.h>

#include "comms.h"

#include "modules/core/command_handler.h"
#include "modules/core/anthem_audio_callback.h"
#include "modules/processing_graph/runtime/anthem_graph_processor.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"
#include "modules/sequencer/runtime/transport.h"
#include "modules/core/visualization/global_visualization_sources.h"

#include "modules/util/id_generator.h"

#include "project.h"

class Anthem {
private:
  bool isAudioCallbackRunning;

  // Singleton shared pointer instance
  static std::unique_ptr<Anthem> instance;

  std::unique_ptr<AnthemAudioCallback> audioCallback;

public:
  // The project model.
  //
  // This is mostly code-generated, and is based on the project model defined in
  // Dart. It is automatically synced with the Dart model, and is used to store
  // the state of the project.
  std::shared_ptr<Project> project;

  // The sequence compiler turns the sequence model from the project into a set
  // of sorted event lists. The compile method on AnthemSequenceCompiler is
  // static, so we don't need an instance of AnthemSequenceCompiler.

  // The sequence store stores the compiled sequences. It is used by the
  // sequencer to get the compiled sequences for playback.
  std::unique_ptr<AnthemRuntimeSequenceStore> sequenceStore;

  // The graph compiler turns the graph topology from the model into processing
  // steps. The compile method on AnthemGraphCompiler is static, so we don't need
  // an instance of AnthemGraphCompiler.

  // The graph processor, which takes the compilation result from the compiler
  // and uses it on the audio thread to process data in the graph
  std::unique_ptr<AnthemGraphProcessor> graphProcessor;

  // The transport contains information about:
  // - The sequence being played
  // - The playhead position
  // - The project tempo
  // - The current playhead reset point and loop points
  std::unique_ptr<Transport> transport;

  // Class for coordinating global visualization that is sent back to the UI,
  // such as CPU burden and transport location.
  std::unique_ptr<GlobalVisualizationSources> globalVisualizationSources;

  // JUCE class for managing audio devices
  juce::AudioDeviceManager audioDeviceManager;

  #ifndef __EMSCRIPTEN__
  // JUCE class for loading and managing plugins
  juce::AudioPluginFormatManager audioPluginFormatManager;
  #endif // #ifndef __EMSCRIPTEN__

  // The UI communication layer. This is used to send and receive messages from
  // the UI.
  AnthemComms comms;

  // Handles command messages from the UI.
  CommandHandler commandHandler;

  Anthem();

  void initialize();

  // Singleton instance getter
  static Anthem& getInstance() {
    if (!instance) {
      instance = std::make_unique<Anthem>();
    }
    return *instance;
  }

  static bool hasInstance() {
    return instance != nullptr;
  }

  static void cleanup() {
    instance.reset();
  }

  void shutdown();

  // Sets up the audio callback
  void startAudioCallback();

  void compileProcessingGraph();
};
