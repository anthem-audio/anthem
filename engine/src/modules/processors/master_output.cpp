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

#include <iostream>

#include "modules/processing_graph/compiler/anthem_process_context.h"

MasterOutputProcessor::MasterOutputProcessor(MasterOutputProcessorModelImpl& _impl)
      : AnthemProcessor("MasterOutput"), MasterOutputProcessorModelBase(_impl) {
  buffer = juce::AudioSampleBuffer(Anthem::NUM_CHANNELS, MAX_AUDIO_BUFFER_SIZE);

  // Audio input port
  config.addAudioInput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  );
}

MasterOutputProcessor::~MasterOutputProcessor() {}

void MasterOutputProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& inputBuffer = context.getInputAudioBuffer(0); // TODO: This isn't correct - buffers need to be in maps by id

  for (int channel = 0; channel < buffer.getNumChannels(); channel++) {
    this->buffer.copyFrom(channel, 0, inputBuffer, channel, 0, numSamples);
  }
}
