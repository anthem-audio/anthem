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

#include "vst3_processor.h"

#ifndef __EMSCRIPTEN__

#include "generated/lib/model/model.h"
#include "modules/core/engine.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#if JUCE_WINDOWS
// JUCE exposes the helper for matching the current thread's DPI-awareness
// context to a native host window in a Windows-only native header.
#include <juce_gui_basics/native/juce_ScopedThreadDPIAwarenessSetter_windows.h>
#endif

namespace anthem {

namespace {
void writeVST3Log(VST3Processor& processor, const juce::String& message) {
  juce::Logger::writeToLog("[VST3:" + juce::String(processor.nodeId()) + "] " + message);
}

} // namespace

VST3Processor::VST3Processor(const VST3ProcessorModelImpl& _impl)
  : Processor("VST3"), VST3ProcessorModelBase(_impl) {}

VST3Processor::~VST3Processor() {
  detachPluginListener();
  hidePluginGUI();
}

void VST3Processor::detachPluginListener() {
  if (pluginInstance == nullptr) {
    return;
  }

  pluginInstance->removeListener(this);
}

void VST3Processor::rebindEditorWindowCloseCallback() {
  if (editorWindow == nullptr) {
    return;
  }

  auto weakSelf = self;
  editorWindow->setCloseCallback([weakSelf]() {
    auto processor = std::dynamic_pointer_cast<VST3Processor>(weakSelf.lock());

    if (processor == nullptr) {
      return;
    }

    processor->hidePluginGUI();
  });
}

// We expect that a valid device is available when this method is called
void VST3Processor::prepareToProcess() {
  writeVST3Log(*this, "prepareToProcess() called for path: " + juce::String(vst3Path()));

  // If the plugin is not initialized, try to initialize it
  tryInitializePlugin();
}

void VST3Processor::process(NodeProcessContext& context, int numSamples) {
  auto& audioOutBuffer = context.getOutputAudioBuffer(VST3ProcessorModelBase::audioOutputPortId);
  auto& eventInBuffer = context.getInputEventBuffer(VST3ProcessorModelBase::eventInputPortId);

  audioOutBuffer.clear();

  if (this->pluginInstance == nullptr) {
    return;
  }

  jassert(numSamples == pluginInstance->getBlockSize());

  for (size_t i = 0; i < eventInBuffer->getNumEvents(); ++i) {
    auto& liveEvent = eventInBuffer->getEvent(i);
    jassert(liveEvent.sampleOffset >= 0 && liveEvent.sampleOffset < numSamples);

    if (liveEvent.event.type == EventType::NoteOn) {
      auto noteOn = juce::MidiMessage::noteOn(liveEvent.event.noteOn.channel + 1,
          liveEvent.event.noteOn.pitch,
          static_cast<uint8_t>(std::round(liveEvent.event.noteOn.velocity * 127.0f)));

      rt_eventBufferForPlugin.addEvent(noteOn, liveEvent.sampleOffset);
    } else if (liveEvent.event.type == EventType::NoteOff) {
      auto noteOff = juce::MidiMessage::noteOff(liveEvent.event.noteOff.channel + 1,
          liveEvent.event.noteOff.pitch,
          static_cast<uint8_t>(std::round(liveEvent.event.noteOff.velocity * 127.0f)));

      rt_eventBufferForPlugin.addEvent(noteOff, liveEvent.sampleOffset);
    } else if (liveEvent.event.type == EventType::AllVoicesOff) {
      for (int channel = 1; channel <= 16; channel++) {
        auto allVoicesOff = juce::MidiMessage::allNotesOff(channel);
        rt_eventBufferForPlugin.addEvent(allVoicesOff, liveEvent.sampleOffset);
      }
    }
  }

  // Process the plugin
  pluginInstance->processBlock(audioOutBuffer, rt_eventBufferForPlugin);

  rt_eventBufferForPlugin.clear();
}

void VST3Processor::initialize(
    std::shared_ptr<ModelBase> selfModel, std::shared_ptr<ModelBase> parentModel) {
  VST3ProcessorModelBase::initialize(selfModel, parentModel);
}

void VST3Processor::tryInitializePlugin() {
  if (pluginInstance != nullptr) {
    writeVST3Log(*this, "Plugin instance already exists. Skipping initialization.");
    return;
  }

  auto& audioPluginFormatManager = Engine::getInstance().audioPluginFormatManager;
  auto& audioDeviceManager = Engine::getInstance().audioDeviceManager;

  auto* device = audioDeviceManager.getCurrentAudioDevice();

  if (device == nullptr) {
    writeVST3Log(*this, "No audio device available. Cannot initialize plugin.");
    return;
  }

  writeVST3Log(*this,
      "Initializing plugin. Sample rate: " + juce::String(device->getCurrentSampleRate()) +
          ", buffer size: " + juce::String(device->getCurrentBufferSizeSamples()));

  // First, scan the VST3 file to get proper plugin descriptions
  juce::VST3PluginFormat vst3Format;
  juce::OwnedArray<juce::PluginDescription> foundPlugins;

  vst3Format.findAllTypesForFile(foundPlugins, vst3Path());

  if (foundPlugins.isEmpty()) {
    writeVST3Log(*this, "No plugins found in VST3 file: " + juce::String(vst3Path()));
    return;
  }

  writeVST3Log(
      *this, "Found " + juce::String(foundPlugins.size()) + " plugin description(s) in file.");
  for (int i = 0; i < foundPlugins.size(); ++i) {
    auto* description = foundPlugins[i];
    writeVST3Log(*this,
        "  [" + juce::String(i) + "] " + description->name + " by " +
            description->manufacturerName + " (" + description->pluginFormatName + ")");
  }

  // Use the first plugin found (not the proper way to do this)
  pluginDescription = *foundPlugins[0];

  auto sampleRate = device->getCurrentSampleRate();
  auto bufferSize = device->getCurrentBufferSizeSamples();
  auto hostBufferChannels = device->getActiveOutputChannels().countNumberOfSetBits();
  auto weakSelf = self;

  audioPluginFormatManager.createPluginInstanceAsync(pluginDescription,
      sampleRate,
      bufferSize,
      [weakSelf, sampleRate, bufferSize, hostBufferChannels](
          std::unique_ptr<juce::AudioPluginInstance> instance, const juce::String& error) mutable {
        auto selfShared = std::dynamic_pointer_cast<VST3Processor>(weakSelf.lock());

        if (selfShared == nullptr) {
          return;
        }

        if (error.isNotEmpty()) {
          writeVST3Log(*selfShared, "Failed to create plugin instance: " + error);
          return;
        }

        if (instance == nullptr) {
          writeVST3Log(*selfShared,
              "Plugin creation callback returned a null instance without an error message.");
          return;
        }

        // Anthem currently exposes a single audio output on VST3 nodes, so
        // auxiliary buses must stay disabled until the graph can represent them.
        instance->disableNonMainBuses();

        const auto requiredProcessChannels =
            juce::jmax(instance->getTotalNumInputChannels(), instance->getTotalNumOutputChannels());

        if (requiredProcessChannels > hostBufferChannels) {
          writeVST3Log(*selfShared,
              "Plugin requires " + juce::String(requiredProcessChannels) +
                  " process channel(s), but Anthem currently allocates " +
                  juce::String(hostBufferChannels) +
                  " channel(s) per plugin buffer. Refusing to load to avoid a host buffer "
                  "overrun.");
          return;
        }

        writeVST3Log(*selfShared,
            "Plugin instance created. Name: " + instance->getName() +
                ", acceptsMidi=" + juce::String(instance->acceptsMidi() ? "true" : "false") +
                ", producesMidi=" + juce::String(instance->producesMidi() ? "true" : "false") +
                ", inputChannels=" + juce::String(instance->getTotalNumInputChannels()) +
                ", outputChannels=" + juce::String(instance->getTotalNumOutputChannels()));

        instance->prepareToPlay(sampleRate, bufferSize);
        writeVST3Log(*selfShared, "prepareToPlay() completed.");

        selfShared->pluginInstance = std::move(instance);
        selfShared->pluginInstance->addListener(selfShared.get());
        writeVST3Log(*selfShared, "Plugin listener attached. Sending PluginLoadedEvent to UI.");

        Response event = PluginLoadedEvent{.nodeId = selfShared->nodeId(),
            .responseBase = ResponseBase{
                .id = -1,
            }};

        auto eventString = rfl::json::write(event);
        Engine::getInstance().comms.send(eventString);

        // The plugin instance is created asynchronously. Open the editor on the message thread
        // and only if the processor still exists by the time we get there.
        juce::MessageManager::callAsync([weakSelf]() {
          auto processor = std::dynamic_pointer_cast<VST3Processor>(weakSelf.lock());

          if (processor == nullptr) {
            return;
          }

          processor->showPluginGUI();
        });
      });
}

void VST3Processor::showPluginGUI() {
  if (!pluginInstance) {
    writeVST3Log(*this, "showPluginGUI() skipped because no plugin instance exists yet.");
    return;
  }

  if (editorWindow != nullptr) {
    // Window already exists, just bring it to front
    writeVST3Log(*this, "Plugin editor window already exists. Bringing it to front.");
    editorWindow->toFront(true);
    return;
  }

  // Create the host window first so the editor can inherit its actual host-window
  // environment during first-time setup.
  //
  // On Windows, Anthem reaches this code from MessageManager::callAsync() after
  // asynchronous plugin creation. That means createEditorIfNeeded() runs from JUCE's
  // hidden message window rather than from a real plugin-host HWND message handler.
  // Some VST3 editors query DPI during createEditorIfNeeded(), and JUCE's Windows
  // host code expects that work to happen with the thread DPI context matched to the
  // actual host window. AudioPluginHost normally gets this naturally because plugin
  // windows are opened from real UI interaction.
  auto pendingEditorWindow = std::make_unique<PluginEditorWindow>(
      pluginDescription.name + " - " + pluginDescription.manufacturerName, std::function<void()>{});

#if JUCE_WINDOWS
  auto* hostPeer = pendingEditorWindow->getPeer();

  if (hostPeer == nullptr) {
    pendingEditorWindow->addToDesktop();
    hostPeer = pendingEditorWindow->getPeer();
  }

  // This is intentionally Windows-only. Windows has a per-thread DPI-awareness
  // context, and JUCE provides a helper to temporarily match that context to the
  // host HWND we just created. Other platforms don't expose an equivalent JUCE
  // helper here, and they don't use the same thread-DPI model that causes this
  // first-open mismatch on Windows.
  std::unique_ptr<juce::ScopedThreadDPIAwarenessSetter> scopedThreadDpiAwarenessSetter;

  if (hostPeer != nullptr) {
    scopedThreadDpiAwarenessSetter =
        std::make_unique<juce::ScopedThreadDPIAwarenessSetter>(hostPeer->getNativeHandle());
  } else {
    writeVST3Log(*this,
        "Plugin editor host window has no native peer yet. Falling back to the current "
        "thread DPI context.");
  }
#else
  if (pendingEditorWindow->getPeer() == nullptr) {
    pendingEditorWindow->addToDesktop();
  }
#endif

  auto pluginEditor =
      std::unique_ptr<juce::AudioProcessorEditor>(pluginInstance->createEditorIfNeeded());

  if (!pluginEditor) {
    writeVST3Log(*this, "createEditorIfNeeded() returned null. No plugin window will be shown.");
    return;
  }

  auto editorIsResizable = pluginEditor->isResizable();

  // Adopt the pre-created host window and finish attaching the editor while the
  // thread DPI context matches that host HWND.
  editorWindow = std::move(pendingEditorWindow);
  rebindEditorWindowCloseCallback();

  editorWindow->setContentOwned(pluginEditor.release(), true);
  editorWindow->setResizable(editorIsResizable, false);

  auto initialBounds = editorWindow->getBounds();

  if (auto* activeWindow = juce::TopLevelWindow::getActiveTopLevelWindow();
      activeWindow != nullptr && activeWindow != editorWindow.get() &&
      !activeWindow->getScreenBounds().isEmpty()) {
    initialBounds = initialBounds.withCentre(activeWindow->getScreenBounds().getCentre());
  } else if (auto* primaryDisplay = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay();
      primaryDisplay != nullptr) {
    initialBounds = initialBounds.withCentre(primaryDisplay->userArea.getCentre());
  } else {
    initialBounds.setPosition(50, 50);
  }

  // Route the initial placement through the window constrainer instead of using
  // centreWithSize(). Some plugins restore a large remembered editor size, and
  // raw centering can place the native title bar off-screen before the user has
  // a chance to move the window.
  initialBounds = editorWindow->getBestEffortOnscreenBounds(initialBounds);

  editorWindow->setBoundsConstrained(initialBounds);
  editorWindow->setVisible(true);

  writeVST3Log(*this,
      "Plugin editor window opened at " + juce::String(editorWindow->getWidth()) + "x" +
          juce::String(editorWindow->getHeight()) + ".");
}

void VST3Processor::hidePluginGUI() {
  if (editorWindow) {
    writeVST3Log(*this, "Closing plugin editor window.");
    editorWindow->clearContentComponent();
    editorWindow->setVisible(false);
    editorWindow.reset();
  }
}

void VST3Processor::audioProcessorParameterChanged(
    juce::AudioProcessor* /*processor*/, int parameterIndex, float newValue) {
  auto weakSelf = self;

  juce::MessageManager::callAsync([weakSelf, parameterIndex, newValue]() {
    auto processor = std::dynamic_pointer_cast<VST3Processor>(weakSelf.lock());

    if (processor == nullptr) {
      return;
    }

    Response event = PluginParameterChangedEvent{.nodeId = processor->nodeId(),
        .parameterIndex = parameterIndex,
        .newValue = newValue,
        .responseBase = ResponseBase{
            .id = -1,
        }};

    auto eventString = rfl::json::write(event);
    Engine::getInstance().comms.send(eventString);
  });
}

void VST3Processor::audioProcessorChanged(
    juce::AudioProcessor* /*processor*/, const juce::AudioProcessor::ChangeDetails& details) {
  auto weakSelf = self;

  juce::MessageManager::callAsync([weakSelf, details]() {
    auto processor = std::dynamic_pointer_cast<VST3Processor>(weakSelf.lock());

    if (processor == nullptr) {
      return;
    }

    Response event = PluginChangedEvent{.nodeId = processor->nodeId(),
        .latencyChanged = details.latencyChanged,
        .parameterInfoChanged = details.parameterInfoChanged,
        .programChanged = details.programChanged,
        .nonParameterStateChanged = details.nonParameterStateChanged,
        .responseBase = ResponseBase{
            .id = -1,
        }};

    auto eventString = rfl::json::write(event);
    Engine::getInstance().comms.send(eventString);
  });
}

void VST3Processor::getState(juce::MemoryBlock& target) {
  if (pluginInstance) {
    return pluginInstance->getStateInformation(target);
  }
}

void VST3Processor::setState(const juce::MemoryBlock& state) {
  if (pluginInstance) {
    writeVST3Log(*this,
        "Applying plugin state block of " + juce::String(static_cast<int>(state.getSize())) +
            " bytes.");
    pluginInstance->setStateInformation(state.getData(), static_cast<int>(state.getSize()));
  }
}

} // namespace anthem

#endif // #ifndef __EMSCRIPTEN__
