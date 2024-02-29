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

ToneGeneratorNode::ToneGeneratorNode() {
  currentSample = 0;
  amplitude = 0.125;
  frequency = 440.0;
  sampleRate = 44100.0; // TODO: This should be dynamic - in the context maybe?

  config.addAudioOutput(
    AnthemProcessorPortConfig(AnthemGraphNodePortType::Audio, "input")
  );
}

ToneGeneratorNode::~ToneGeneratorNode() {}

void ToneGeneratorNode::process(AnthemProcessContext& context) {
  auto& buffer = context.getOutputAudioBuffer(0);

  // Generate a sine wave
  for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
    const float value = amplitude * std::sin(
      2.0 * juce::MathConstants<float>::pi * frequency * currentSample / sampleRate
    );

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel) {
      buffer.getWritePointer(channel)[sample] = value;
    }

    currentSample++;
  }
}

std::shared_ptr<AnthemGraphNodePort> ToneGeneratorNode::getOutput() {
  return config.getAudioOutput(0);
}
