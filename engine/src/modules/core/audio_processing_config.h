/*
  Copyright (C) 2026 Joshua Wade

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

#include <juce_core/juce_core.h>
#include <memory>

#if JUCE_MAC
#include <juce_audio_basics/juce_audio_basics.h>
#endif

namespace anthem {

struct AudioProcessingConfigDto;

struct AudioProcessingConfig {
  double sampleRate = 0.0;
  int blockSize = 0;
  int inputChannelCount = 0;
  int outputChannelCount = 0;

#if JUCE_MAC
  juce::AudioWorkgroup macAudioWorkgroup;
#endif

  bool isValid() const {
    return sampleRate > 0.0 && blockSize > 0 && outputChannelCount > 0;
  }

  std::shared_ptr<AudioProcessingConfigDto> toDto() const;
  static AudioProcessingConfig fromDto(const AudioProcessingConfigDto& dto);
};

} // namespace anthem
