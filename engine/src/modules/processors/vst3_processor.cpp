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

#include "vst3_processor.h"

#ifndef __EMSCRIPTEN__

#include "modules/processing_graph/compiler/anthem_process_context.h"

#include "modules/core/anthem.h"
#include "generated/lib/model/model.h"

VST3Processor::VST3Processor(const VST3ProcessorModelImpl& _impl)
      : AnthemProcessor("VST3"), VST3ProcessorModelBase(_impl) {
  // Nothing to do here
}

VST3Processor::~VST3Processor() {
  // Nothing to do here
  hidePluginGUI();
}

// We expect that a valid device is available when this method is called
void VST3Processor::prepareToProcess() {
  // If the plugin is not initialized, try to initialize it
  tryInitializePlugin();
}

void VST3Processor::process(AnthemProcessContext& context, int numSamples) {
  
  auto& audioOutBuffer = context.getOutputAudioBuffer(VST3ProcessorModelBase::audioOutputPortId);
  auto& eventInBuffer = context.getInputEventBuffer(VST3ProcessorModelBase::eventInputPortId);

  audioOutBuffer.clear();

  if (this->pluginInstance == nullptr) {
    return;
  }

  jassert(numSamples == pluginInstance->getBlockSize());

  for (size_t i = 0; i < eventInBuffer->getNumEvents(); ++i) {
    auto& liveEvent = eventInBuffer->getEvent(i);

    if (liveEvent.event.type == AnthemEventType::NoteOn) {
      auto noteOn = juce::MidiMessage::noteOn(
        liveEvent.event.noteOn.channel + 1, liveEvent.event.noteOn.pitch, static_cast<uint8_t>(std::round(liveEvent.event.noteOn.velocity * 127.0f))
      );

      rt_eventBufferForPlugin.addEvent(noteOn, static_cast<int>(std::round(liveEvent.time)));
    }
    else if (liveEvent.event.type == AnthemEventType::NoteOff) {
      auto noteOff = juce::MidiMessage::noteOff(
        liveEvent.event.noteOff.channel + 1, liveEvent.event.noteOff.pitch, static_cast<uint8_t>(std::round(liveEvent.event.noteOff.velocity * 127.0f))
      );

      rt_eventBufferForPlugin.addEvent(noteOff, static_cast<int>(std::round(liveEvent.time)));
    }
    else if (liveEvent.event.type == AnthemEventType::AllVoicesOff) {
      for (int i = 1; i <= 16; i++) {
        auto allVoicesOff = juce::MidiMessage::allNotesOff(i);
        rt_eventBufferForPlugin.addEvent(allVoicesOff, static_cast<int>(std::round(liveEvent.time)));
      }
    }
  }

  // Process the plugin
  pluginInstance->processBlock(audioOutBuffer, rt_eventBufferForPlugin);

  rt_eventBufferForPlugin.clear();
}

void VST3Processor::initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
  VST3ProcessorModelBase::initialize(self, parent);
}

void VST3Processor::tryInitializePlugin() {
  auto& audioPluginFormatManager = Anthem::getInstance().audioPluginFormatManager;
  auto& audioDeviceManager = Anthem::getInstance().audioDeviceManager;

  auto* device = audioDeviceManager.getCurrentAudioDevice();

  if (device == nullptr) {
    std::cerr << "No audio device available. Cannot initialize VST3 plugin." << std::endl;
    return;
  }

  // First, scan the VST3 file to get proper plugin descriptions
  juce::VST3PluginFormat vst3Format;
  juce::OwnedArray<juce::PluginDescription> foundPlugins;
  
  vst3Format.findAllTypesForFile(foundPlugins, vst3Path());

  if (foundPlugins.isEmpty()) {
    // We need proper error handling for this
    std::cerr << "No plugins found in VST3 file: " << vst3Path() << std::endl;
    return;
  }

  // Use the first plugin found (not the proper way to do this)
  pluginDescription = *foundPlugins[0];

  auto sampleRate = device->getCurrentSampleRate();
  auto bufferSize = device->getCurrentBufferSizeSamples();

  audioPluginFormatManager.createPluginInstanceAsync(
    pluginDescription,
    sampleRate,
    bufferSize,
    [this, sampleRate, bufferSize](std::unique_ptr<juce::AudioPluginInstance> instance, const juce::String& error) {
      if (error.isNotEmpty()) {
        std::cerr << "Failed to create plugin instance: " << error.toStdString() << std::endl;
        return;
      }

      hasEditor = instance->hasEditor();
      instance->prepareToPlay(sampleRate, bufferSize);
      pluginInstance = std::move(instance);
      pluginInstance->addListener(this);

      Response event = PluginLoadedEvent {
        .nodeId = this->nodeId(),
        .responseBase = ResponseBase {
          .id = -1,
        }
      };

      auto eventString = rfl::json::write(event);
      Anthem::getInstance().comms.send(eventString);

      showPluginGUI();
    }
  );
}

void VST3Processor::showPluginGUI() {
  if (!pluginInstance || !hasEditor) {
    return;
  }

  if (editorWindow != nullptr) {
    // Window already exists, just bring it to front
    editorWindow->toFront(true);
    return;
  }

  // Create the plugin editor
  pluginEditor = std::unique_ptr<juce::AudioProcessorEditor>(pluginInstance->createEditor());
  
  if (!pluginEditor) {
    std::cerr << "Failed to create plugin editor" << std::endl;
    return;
  }

  // Create a window to host the editor with close callback
  editorWindow = std::make_unique<PluginEditorWindow>(
    pluginDescription.name + " - " + pluginDescription.manufacturerName,
    [this]() { hidePluginGUI(); }
  );

  editorWindow->setContentOwned(pluginEditor.release(), true);
  editorWindow->setResizable(false, false);
  editorWindow->setUsingNativeTitleBar(true);
  
  // Center the window on screen
  editorWindow->centreWithSize(editorWindow->getWidth(), editorWindow->getHeight());
  editorWindow->setVisible(true);
}

void VST3Processor::hidePluginGUI() {
  if (editorWindow) {
    editorWindow->setVisible(false);
    editorWindow.reset();
  }
  pluginEditor.reset();
}

void VST3Processor::audioProcessorParameterChanged(juce::AudioProcessor* processor, int parameterIndex, float newValue) {
  juce::MessageManager::callAsync([this, parameterIndex, newValue]() {
    Response event = PluginParameterChangedEvent {
      .nodeId = this->nodeId(),
      .parameterIndex = parameterIndex,
      .newValue = newValue,
      .responseBase = ResponseBase {
        .id = -1,
      }
    };

    auto eventString = rfl::json::write(event);
    Anthem::getInstance().comms.send(eventString);
  });
}

void VST3Processor::audioProcessorChanged(juce::AudioProcessor* processor, const juce::AudioProcessor::ChangeDetails& details) {
  juce::MessageManager::callAsync([this, details]() {
    Response event = PluginChangedEvent {
      .nodeId = this->nodeId(),
      .latencyChanged = details.latencyChanged,
      .parameterInfoChanged = details.parameterInfoChanged,
      .programChanged = details.programChanged,
      .nonParameterStateChanged = details.nonParameterStateChanged,
      .responseBase = ResponseBase {
        .id = -1,
      }
    };

    auto eventString = rfl::json::write(event);
    Anthem::getInstance().comms.send(eventString);
  });
}

void VST3Processor::getState(juce::MemoryBlock& target) {
  if (pluginInstance) {
    return pluginInstance->getStateInformation(target);
  }
}

void VST3Processor::setState(const juce::MemoryBlock& state) {
  if (pluginInstance) {
    pluginInstance->setStateInformation(state.getData(), static_cast<int>(state.getSize()));
  }
}

#endif // #ifndef __EMSCRIPTEN__
