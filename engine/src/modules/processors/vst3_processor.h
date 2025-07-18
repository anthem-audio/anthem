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

#pragma once

#include <memory>

#include <juce_audio_processors/juce_audio_processors.h>

#include "generated/lib/model/model.h"
#include "modules/processing_graph/processor/anthem_processor.h"

class PluginEditorWindow : public juce::DocumentWindow {
public:
  PluginEditorWindow(const juce::String& name, std::function<void()> onClose)
    : DocumentWindow(name, juce::Colours::lightgrey, 
                    DocumentWindow::closeButton | DocumentWindow::minimiseButton),
      closeCallback(onClose) {
    setUsingNativeTitleBar(true);
  }

  void closeButtonPressed() override {
    if (closeCallback) {
      closeCallback();
    }
  }

private:
  std::function<void()> closeCallback;
};

class VST3Processor : public AnthemProcessor, public VST3ProcessorModelBase, public juce::AudioProcessorListener {
private:
  juce::PluginDescription pluginDescription;

  bool hasEditor = false;

  std::unique_ptr<juce::AudioPluginInstance> pluginInstance;

  juce::MidiBuffer rt_eventBufferForPlugin;

  std::unique_ptr<juce::DocumentWindow> editorWindow;
  std::unique_ptr<juce::AudioProcessorEditor> pluginEditor;

  void showPluginGUI();
  void hidePluginGUI();
public:
  VST3Processor(const VST3ProcessorModelImpl& _impl);
  ~VST3Processor() override;

  VST3Processor(const VST3Processor&) = delete;
  VST3Processor& operator=(const VST3Processor&) = delete;

  VST3Processor(VST3Processor&&) noexcept = default;
  VST3Processor& operator=(VST3Processor&&) noexcept = default;

  void prepareToProcess() override;
  void process(AnthemProcessContext& context, int numSamples) override;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override;

  void tryInitializePlugin();

  void audioProcessorParameterChanged(juce::AudioProcessor* processor, int parameterIndex, float newValue) override;
  void audioProcessorChanged(juce::AudioProcessor* processor, const juce::AudioProcessor::ChangeDetails& details) override;

  void getState(juce::MemoryBlock& target) override;
  void setState(const juce::MemoryBlock& state) override;
};
