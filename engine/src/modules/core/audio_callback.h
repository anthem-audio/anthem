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

#pragma once

#include "modules/processors/master_output.h"

#include <juce_audio_devices/juce_audio_devices.h>
#include <memory>

namespace anthem {

class AudioBlockProcessor;
class AudioSessionController;
class Project;

class AudioCallback : public juce::AudioIODeviceCallback {
private:
  double rt_sampleRate = 0.0;

  // There is a shared_ptr reference to the processor here to ensure that it is
  // not deleted, but it should never be accessed from the callback, since
  // shared_ptr is not real-time safe.
  std::shared_ptr<MasterOutputProcessor> masterOutputProcessorSharedPtr;

  MasterOutputProcessor* masterOutputProcessor;

  AudioBlockProcessor& audioBlockProcessor;
  AudioSessionController& audioSessionController;
public:
  AudioCallback(Project& project,
      AudioBlockProcessor& audioBlockProcessor,
      AudioSessionController& audioSessionController);

  void audioDeviceIOCallbackWithContext(const float* const* inputChannelData,
      int numInputChannels,
      float* const* outputChannelData,
      int numOutputChannels,
      int numSamples,
      const juce::AudioIODeviceCallbackContext& context) override;
  void audioDeviceAboutToStart(juce::AudioIODevice* device) override;
  void audioDeviceStopped() override;
};

} // namespace anthem
