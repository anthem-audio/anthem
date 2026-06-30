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

#include "audio_processing_config.h"

#include "messages/messages.h"

namespace anthem {

std::shared_ptr<AudioProcessingConfigDto> AudioProcessingConfig::toDto() const {
  auto dto = std::make_shared<AudioProcessingConfigDto>();
  dto->sampleRate = sampleRate;
  dto->blockSize = blockSize;
  dto->inputChannelCount = inputChannelCount;
  dto->outputChannelCount = outputChannelCount;
  return dto;
}

AudioProcessingConfig AudioProcessingConfig::fromDto(const AudioProcessingConfigDto& dto) {
  return AudioProcessingConfig{
      .sampleRate = dto.sampleRate,
      .blockSize = static_cast<int>(dto.blockSize),
      .inputChannelCount = static_cast<int>(dto.inputChannelCount),
      .outputChannelCount = static_cast<int>(dto.outputChannelCount),
  };
}

} // namespace anthem
