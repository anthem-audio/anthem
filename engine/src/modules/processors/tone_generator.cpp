/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

#include "tone_generator.h"

#include "modules/core/anthem.h"
#include "modules/processing_graph/compiler/anthem_node_process_context.h"

#include <cmath>
#include <iostream>

namespace {
constexpr float kMinFrequencyHz = 1.0f;
constexpr float kMaxFrequencyHz = 22500.0f;
} // namespace

ToneGeneratorProcessor::ToneGeneratorProcessor(const ToneGeneratorProcessorModelImpl& _impl)
  : AnthemProcessor("ToneGenerator"), ToneGeneratorProcessorModelBase(_impl) {
  phase = 0;

  hasNoteOverride = false;
  noteOverride = 0;
}

ToneGeneratorProcessor::~ToneGeneratorProcessor() {}

void ToneGeneratorProcessor::prepareToProcess() {
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);
  sampleRate = currentDevice->getCurrentSampleRate();
}

void ToneGeneratorProcessor::process(AnthemNodeProcessContext& context, int numSamples) {
  auto& audioOutBuffer =
      context.getOutputAudioBuffer(ToneGeneratorProcessorModelBase::audioOutputPortId);

  auto& frequencyControlBuffer =
      context.getInputControlBuffer(ToneGeneratorProcessorModelBase::frequencyPortId);
  auto& amplitudeControlBuffer =
      context.getInputControlBuffer(ToneGeneratorProcessorModelBase::amplitudePortId);

  // Process incoming events
  auto& eventInBuffer =
      context.getInputEventBuffer(ToneGeneratorProcessorModelBase::eventInputPortId);

  for (size_t i = 0; i < eventInBuffer->getNumEvents(); ++i) {
    auto& liveEvent = eventInBuffer->getEvent(i);

    if (liveEvent.event.type == AnthemEventType::NoteOn) {
      hasNoteOverride = true;
      noteOverride = liveEvent.event.noteOn.pitch;

      // We're deliberately ignoring the live timing information here for
      // simplicity. This would not be correct for a real device - we should be
      // reading liveEvent.sampleOffset, which represents the sample offset
      // from the start of the processing block.
    }
  }

  // Generate a sine wave
  for (int sample = 0; sample < numSamples; ++sample) {
    auto normalizedFrequency = frequencyControlBuffer.getReadPointer(0)[sample];
    auto amplitude = amplitudeControlBuffer.getReadPointer(0)[sample];
    jassert(juce::jlimit(0.0f, 1.0f, normalizedFrequency) == normalizedFrequency);
    jassert(juce::jlimit(0.0f, 1.0f, amplitude) == amplitude);

    auto frequency = normalizedFrequency * (kMaxFrequencyHz - kMinFrequencyHz) + kMinFrequencyHz;

    if (hasNoteOverride) {
      const auto semitoneOffset = static_cast<float>(noteOverride - 69);
      frequency = 440.0f * std::pow(2.0f, semitoneOffset / 12.0f);
    }

    const float value = amplitude * (float)std::sin(2.0 * juce::MathConstants<float>::pi * phase);

    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      audioOutBuffer.getWritePointer(channel)[sample] = value;
    }

    // Increment phase based on frequency
    phase = std::fmod((phase + (frequency / sampleRate)), 1.0);
  }
}

void ToneGeneratorProcessor::initialize(
    std::shared_ptr<AnthemModelBase> selfModel, std::shared_ptr<AnthemModelBase> parentModel) {
  ToneGeneratorProcessorModelBase::initialize(selfModel, parentModel);

  // Empty for now...
}
