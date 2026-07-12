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

#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <cstdint>

namespace anthem {

class GlobalVisualizationSources;
class GraphProcessor;
class Transport;

struct AudioBlockProcessResult {
  bool didProcessGraph = false;
  int processedSamples = 0;
  bool didReachScheduledStop = false;
};

class AudioBlockProcessor {
private:
  Transport& transport;
  RuntimeSequenceStore& sequenceStore;
  RuntimeAutomationSequenceStore& automationSequenceStore;
  GraphProcessor& graphProcessor;
  GlobalVisualizationSources& globalVisualizationSources;
public:
  AudioBlockProcessor(Transport& transport,
      RuntimeSequenceStore& sequenceStore,
      RuntimeAutomationSequenceStore& automationSequenceStore,
      GraphProcessor& graphProcessor,
      GlobalVisualizationSources& globalVisualizationSources);

  AudioBlockProcessResult processAudioBlock(
      int numSamples, double sampleRate, uint64_t audioProcessingConfigGeneration);
};

} // namespace anthem
