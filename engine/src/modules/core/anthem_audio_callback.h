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

#pragma once

#include <memory>
#include <chrono>

#include <juce_audio_devices/juce_audio_devices.h>

#include "modules/core/constants.h"
#include "modules/processors/master_output.h"

#include "modules/core/visualization/global_visualization_sources.h"

class Anthem;

class AnthemAudioCallback : public juce::AudioIODeviceCallback
{
private:
  double sampleRate = -1.0;

  int64_t lastDebugOutputTime;

  // There is a shared_ptr reference to the processor here to ensure that it is
  // not deleted, but it should never be accessed from the callback, since
  // shared_ptr is not real-time safe.
  std::shared_ptr<MasterOutputProcessor> masterOutputProcessorSharedPtr;

  MasterOutputProcessor* masterOutputProcessor;

  // We will assume the Anthem application class is always available. This is
  // normally stored in a shared_ptr, which we can't use from the audio thread
  // since it's not real-time safe.
  Anthem* anthem;

  // This is a reference to the CPU burden provider. The audio callback
  // calculates the CPU burden every time the audio callback is called, and sets
  // it here.
  CpuVisualizationProvider* cpuBurdenProvider;

  // This is a reference to the playhead provider. The audio callback updates
  // the playhead position every time the audio callback is called, and sets it
  // here.
  PlayheadPositionVisualizationProvider* playheadPositionProvider;

  // This is a reference to the playhead sequence ID provider. The audio
  // callback updates the playhead sequence ID every time the audio callback is
  // called, and sets it here.
  PlayheadSequenceIdVisualizationProvider* playheadSequenceIdProvider;
public:
  AnthemAudioCallback(Anthem* anthem);

  void audioDeviceIOCallbackWithContext(const float* const* inputChannelData,
                                                   int numInputChannels,
                                                   float* const* outputChannelData,
                                                   int numOutputChannels,
                                                   int numSamples,
                                                   const juce::AudioIODeviceCallbackContext& context) override;
  void audioDeviceAboutToStart(juce::AudioIODevice* device) override;
  void audioDeviceStopped() override;
};
