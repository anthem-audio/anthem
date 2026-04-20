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

#include "simple_midi_generator.h"

#include "modules/core/anthem.h"
#include "modules/processing_graph/compiler/anthem_node_process_context.h"
#include "modules/sequencer/events/event.h"

namespace anthem {

SimpleMidiGeneratorProcessor::SimpleMidiGeneratorProcessor(
    const SimpleMidiGeneratorProcessorModelImpl& _impl)
  : Processor("SimpleMidiGenerator"), SimpleMidiGeneratorProcessorModelBase(_impl) {
  durationSamples = 22050;
  velocity = 80;
  noteOn = false;

  currentNote = 0;
  currentNoteId = invalidLiveNoteId;
  currentNoteDuration = 0;
}

SimpleMidiGeneratorProcessor::~SimpleMidiGeneratorProcessor() {}

void SimpleMidiGeneratorProcessor::prepareToProcess() {
  auto* currentDevice = Engine::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);
  sampleRate = currentDevice->getCurrentSampleRate();
}

void SimpleMidiGeneratorProcessor::process(NodeProcessContext& context, int numSamples) {
  auto& eventOutBuffer =
      context.getOutputEventBuffer(SimpleMidiGeneratorProcessorModelBase::eventOutputPortId);

  if (!noteOn) {
    currentNote = 50;
    currentNoteId = context.rt_allocateLiveNoteId();
    currentNoteDuration = 0;
    eventOutBuffer->addEvent(LiveEvent{.sampleOffset = 0.0,
        .liveId = currentNoteId,
        .event = Event(NoteOnEvent(currentNote, 0, static_cast<float>(velocity), 0.0f))});

    noteOn = true;
  }

  size_t samplesLeft = static_cast<size_t>(numSamples);

  while (samplesLeft > 0) {
    size_t samplesToProcess = std::min(samplesLeft, durationSamples - currentNoteDuration);

    currentNoteDuration += samplesToProcess;
    samplesLeft -= samplesToProcess;

    if (currentNoteDuration >= durationSamples) {
      LiveEvent noteOffEvent = LiveEvent{.sampleOffset = 0.0,
          .liveId = currentNoteId,
          .event = Event(NoteOffEvent(currentNote, 0, 0.0f))};

      eventOutBuffer->addEvent(noteOffEvent);

      currentNoteDuration = 0;

      currentNote += 2;

      if (currentNote > 80) {
        currentNote = 50;
      }

      currentNoteId = context.rt_allocateLiveNoteId();

      LiveEvent noteOnEvent = LiveEvent{.sampleOffset = 0.0,
          .liveId = currentNoteId,
          .event = Event(NoteOnEvent(currentNote, 0, static_cast<float>(velocity), 0.0f))};

      eventOutBuffer->addEvent(noteOnEvent);
    }
  }
}

} // namespace anthem
