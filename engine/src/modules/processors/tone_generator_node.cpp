/*
  Copyright (C) 2024 Joshua Wade

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

#include "tone_generator_node.h"

#include <iostream>
#include <cmath>

#include "anthem_process_context.h"

ToneGeneratorNode::ToneGeneratorNode() : AnthemProcessor("ToneGenerator") {
  phase = 0;
  // amplitude = 0.125;
  // this->frequency = frequency;
  sampleRate = 44100.0; // TODO: This should be dynamic - in the context maybe?

  // Audio port config

  // Audio output port
  config.addAudioOutput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  );

  // Control port config

  // Frequency
  config.addControlInput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Control, 0),
    std::make_shared<AnthemProcessorParameterConfig>(0, 440.0, 0.0, 20000.0)
  );

  // Amplitude
  config.addControlInput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Control, 1),
    std::make_shared<AnthemProcessorParameterConfig>(1, 0.125, 0.0, 1.0)
  );
}

ToneGeneratorNode::~ToneGeneratorNode() {}

void ToneGeneratorNode::process(AnthemProcessContext& context, int numSamples) {
  auto& audioOutBuffer = context.getOutputAudioBuffer(0);

  auto& frequencyControlBuffer = context.getInputControlBuffer(0);
  auto& amplitudeControlBuffer = context.getInputControlBuffer(1);

  // Generate a sine wave
  for (int sample = 0; sample < numSamples; ++sample) {
    auto frequency = frequencyControlBuffer.getReadPointer(0)[sample];
    auto amplitude = amplitudeControlBuffer.getReadPointer(0)[sample];

    const float value = amplitude * std::sin(
      2.0 * juce::MathConstants<float>::pi * phase
    );

    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      audioOutBuffer.getWritePointer(channel)[sample] = value;
    }

    // Increment phase based on frequency
    phase = std::fmod((phase + (frequency / sampleRate)), 1.0);
  }
}
