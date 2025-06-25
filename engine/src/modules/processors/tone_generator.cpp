/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include <iostream>
#include <cmath>

#include "modules/processing_graph/compiler/anthem_process_context.h"

ToneGeneratorProcessor::ToneGeneratorProcessor(const ToneGeneratorProcessorModelImpl& _impl)
      : AnthemProcessor("ToneGenerator"), ToneGeneratorProcessorModelBase(_impl) {
  phase = 0;
  // amplitude = 0.125;
  // this->frequency = frequency;
  sampleRate = 48000.0; // TODO: This should be dynamic - in the context maybe?

  hasNoteOverride = false;
  noteOverride = 0;
}

ToneGeneratorProcessor::~ToneGeneratorProcessor() {}

void ToneGeneratorProcessor::prepareToProcess() {}

void ToneGeneratorProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& audioOutBuffer = context.getOutputAudioBuffer(ToneGeneratorProcessorModelBase::audioOutputPortId);

  auto& frequencyControlBuffer = context.getInputControlBuffer(ToneGeneratorProcessorModelBase::frequencyPortId);
  auto& amplitudeControlBuffer = context.getInputControlBuffer(ToneGeneratorProcessorModelBase::amplitudePortId);

  // Process incoming events
  auto& eventInBuffer = context.getInputEventBuffer(ToneGeneratorProcessorModelBase::eventInputPortId);

  for (size_t i = 0; i < eventInBuffer->getNumEvents(); ++i) {
    auto& liveEvent = eventInBuffer->getEvent(i);

    if (liveEvent.event.type == AnthemEventType::NoteOn) {
      hasNoteOverride = true;
      noteOverride = liveEvent.event.noteOn.pitch;

      // We're deliberately ignoring the live timing information here for
      // simplicity. This would not be correct for a real device - we should be
      // reading liveEvent.time, which represents the time since the start of
      // the processing block.

    }
  }

  // Generate a sine wave
  for (int sample = 0; sample < numSamples; ++sample) {
    auto frequency = frequencyControlBuffer.getReadPointer(0)[sample];
    auto amplitude = amplitudeControlBuffer.getReadPointer(0)[sample];

    if (hasNoteOverride) {
      frequency = 440.0f * std::pow(2.0f, (noteOverride - 69) / 12.0f);
    }

    const float value = amplitude * (float) std::sin(
      2.0 * juce::MathConstants<float>::pi * phase
    );

    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      audioOutBuffer.getWritePointer(channel)[sample] = value;
    }

    // Increment phase based on frequency
    phase = std::fmod((phase + (frequency / sampleRate)), 1.0);
  }
}

void ToneGeneratorProcessor::initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
  ToneGeneratorProcessorModelBase::initialize(self, parent);

  // Empty for now...
}
