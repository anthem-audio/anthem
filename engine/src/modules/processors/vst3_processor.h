/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#ifndef __EMSCRIPTEN__

#include <memory>

#include <juce_audio_processors/juce_audio_processors.h>

#include "generated/lib/model/processing_graph/processors/vst3_processor.h"
#include "modules/processing_graph/processor/anthem_processor.h"

class PluginEditorWindow : public juce::DocumentWindow {
public:
  PluginEditorWindow(
    const juce::String& name,
    std::function<void()> onClose
  )
    : DocumentWindow(name, juce::Colours::lightgrey, 
                    DocumentWindow::closeButton | DocumentWindow::minimiseButton),
      closeCallback(onClose),
      constrainer(*this) {
    setUsingNativeTitleBar(true);
    setConstrainer(&constrainer);
  }

  ~PluginEditorWindow() override = default;

  void setCloseCallback(std::function<void()> onClose) {
    closeCallback = std::move(onClose);
  }

  void closeButtonPressed() override {
    if (closeCallback) {
      closeCallback();
    }
  }

protected:
  void childBoundsChanged(juce::Component* child) override {
    juce::DocumentWindow::childBoundsChanged(child);

    if (child == getContentComponent()) {
      // Some plugin editors resize themselves after opening. Re-apply the window
      // constrainer so the native title bar stays reachable even if the editor
      // restores a large remembered size.
      setBoundsConstrained(getBestEffortOnscreenBounds(getBounds()));
    }
  }

private:
  juce::BorderSize<int> getNativeFrameBorder() const {
    if (auto* peer = getPeer()) {
      if (const auto frameSize = peer->getFrameSizeIfPresent()) {
        return *frameSize;
      }
    }

    return {};
  }

  static juce::Rectangle<int> clampBoundsToArea(
    juce::Rectangle<int> bounds,
    const juce::Rectangle<int>& area
  ) {
    if (bounds.getWidth() >= area.getWidth()) {
      bounds.setX(area.getX());
    }
    else {
      bounds.setX(
        juce::jlimit(area.getX(), area.getRight() - bounds.getWidth(), bounds.getX())
      );
    }

    if (bounds.getHeight() >= area.getHeight()) {
      bounds.setY(area.getY());
    }
    else {
      bounds.setY(
        juce::jlimit(area.getY(), area.getBottom() - bounds.getHeight(), bounds.getY())
      );
    }

    return bounds;
  }

public:
  juce::Rectangle<int> getBestEffortOnscreenBounds(
    juce::Rectangle<int> bounds
  ) const {
    auto framedBounds = bounds;
    getNativeFrameBorder().addTo(framedBounds);

    auto* display =
      juce::Desktop::getInstance().getDisplays().getDisplayForRect(framedBounds);

    if (display == nullptr) {
      display = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay();
    }

    if (display == nullptr) {
      return bounds;
    }

    framedBounds = clampBoundsToArea(framedBounds, display->userArea);
    getNativeFrameBorder().subtractFrom(framedBounds);

    return framedBounds;
  }

  class DecoratorConstrainer final
    : public juce::BorderedComponentBoundsConstrainer {
  public:
    explicit DecoratorConstrainer(juce::DocumentWindow& windowIn)
      : window(windowIn) {}

    juce::ComponentBoundsConstrainer* getWrappedConstrainer() const override {
      auto* editor =
        dynamic_cast<juce::AudioProcessorEditor*>(window.getContentComponent());
      return editor != nullptr ? editor->getConstrainer() : nullptr;
    }

    juce::BorderSize<int> getAdditionalBorder() const override {
      const auto nativeFrame = [&]() -> juce::BorderSize<int> {
        if (auto* peer = window.getPeer()) {
          if (const auto frameSize = peer->getFrameSizeIfPresent()) {
            return *frameSize;
          }
        }

        return {};
      }();

      return nativeFrame.addedTo(window.getContentComponentBorder());
    }

  private:
    juce::DocumentWindow& window;
  };

  std::function<void()> closeCallback;
  DecoratorConstrainer constrainer;
};

class VST3Processor : public AnthemProcessor, public VST3ProcessorModelBase, public juce::AudioProcessorListener {
private:
  juce::PluginDescription pluginDescription;

  std::unique_ptr<juce::AudioPluginInstance> pluginInstance;

  juce::MidiBuffer rt_eventBufferForPlugin;

  std::unique_ptr<PluginEditorWindow> editorWindow;

  void detachPluginListener();
  void rebindEditorWindowCloseCallback();
  void showPluginGUI();
  void hidePluginGUI();
public:
  VST3Processor(const VST3ProcessorModelImpl& _impl);
  ~VST3Processor() override;

  VST3Processor(const VST3Processor&) = delete;
  VST3Processor& operator=(const VST3Processor&) = delete;
  VST3Processor(VST3Processor&&) noexcept = default;
  VST3Processor& operator=(VST3Processor&&) noexcept = delete;

  void prepareToProcess() override;
  void process(AnthemNodeProcessContext& context, int numSamples) override;

  void initialize(
    std::shared_ptr<AnthemModelBase> selfModel,
    std::shared_ptr<AnthemModelBase> parentModel
  ) override;

  void tryInitializePlugin();

  void audioProcessorParameterChanged(juce::AudioProcessor* processor, int parameterIndex, float newValue) override;
  void audioProcessorChanged(juce::AudioProcessor* processor, const juce::AudioProcessor::ChangeDetails& details) override;

  void getState(juce::MemoryBlock& target) override;
  void setState(const juce::MemoryBlock& state) override;
};

#endif // #ifndef __EMSCRIPTEN__
