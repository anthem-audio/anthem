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

#include "master_output.h"
#include "modules/core/anthem.h"
#include "modules/processing_graph/compiler/anthem_process_context.h"

#include <juce_audio_basics/juce_audio_basics.h>

#include <iostream>

MasterOutputProcessor::MasterOutputProcessor(const MasterOutputProcessorModelImpl& _impl)
      : AnthemProcessor("MasterOutput"), MasterOutputProcessorModelBase(_impl) {}

MasterOutputProcessor::~MasterOutputProcessor() {}

void MasterOutputProcessor::prepareToProcess() {
  auto* device = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  if (!device) {
    std::cerr << "Error: No audio device is currently set." << std::endl;
    return;
  }

  auto outputChannelsMask = device->getActiveOutputChannels();
  auto outputChannels = outputChannelsMask.countNumberOfSetBits();
  auto bufferSize = device->getCurrentBufferSizeSamples();
  buffer = juce::AudioSampleBuffer(outputChannels, bufferSize);
}

void MasterOutputProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& inputBuffer = context.getInputAudioBuffer(MasterOutputProcessorModelBase::inputPortId);

  for (int channel = 0; channel < buffer.getNumChannels(); channel++) {
    this->buffer.copyFrom(channel, 0, inputBuffer, channel, 0, numSamples);
  }
}
