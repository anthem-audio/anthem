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

  this->tryInitializePlugin();
}

void VST3Processor::tryInitializePlugin() {
  auto& audioPluginFormatManager = Anthem::getInstance().audioPluginFormatManager;
  auto& audioDeviceManager = Anthem::getInstance().audioDeviceManager;

  auto* device = audioDeviceManager.getCurrentAudioDevice();

  // If no device is available, we may still be starting the application. We
  // will retry again later.
  if (device == nullptr) {
    auto node = std::static_pointer_cast<Node>(parent.lock());

    auto nodeId = node->id();
    juce::Timer::callAfterDelay(1000, [nodeId]() {
      // We need to find this node via the node graph, in case our "this"
      // pointer is no longer valid (likely due to a move during
      // initialization).

      auto project = Anthem::getInstance().project;
      auto node = project->processingGraph()->nodes()->at(nodeId);
      std::shared_ptr<VST3Processor> processor = rfl::visit(
        [&](auto& item) {
          using Name = typename std::decay_t<decltype(item)>::Name;
          if constexpr (std::is_same<Name, rfl::Literal<"VST3ProcessorModel">>()) {
            return item.value();
          }

          return std::shared_ptr<VST3Processor>(nullptr);
        },
        node->processor().value()
      );

      if (processor == nullptr) {
        std::cerr << "Failed to find processor for node: " << nodeId << std::endl;
        return;
      }

      processor->tryInitializePlugin();
    });

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
