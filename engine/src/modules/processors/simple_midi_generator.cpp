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

#include "simple_midi_generator.h"

#include "modules/processing_graph/compiler/anthem_process_context.h"
#include "modules/sequencer/events/event.h"

SimpleMidiGeneratorProcessor::SimpleMidiGeneratorProcessor(const SimpleMidiGeneratorProcessorModelImpl& _impl)
    : AnthemProcessor("SimpleMidiGenerator"), SimpleMidiGeneratorProcessorModelBase(_impl) {
  sampleRate = 44100; // TODO: This should be dynamic - in the context maybe?
  durationSamples = 22050;
  velocity = 80;
  noteOn = false;

  currentNote = 0;
  currentNoteId = 0;
  currentNoteDuration = 0;
}

SimpleMidiGeneratorProcessor::~SimpleMidiGeneratorProcessor() {}

void SimpleMidiGeneratorProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& midiOutBuffer = context.getOutputNoteEventBuffer(SimpleMidiGeneratorProcessorModelBase::midiOutputPortId);

  if (!noteOn) {
    currentNote = 50;
    currentNoteId = 0;
    currentNoteDuration = 0;
    midiOutBuffer->addEvent({
      AnthemProcessorEventType::NoteOn,
      NoteOnEvent(currentNote, 0, static_cast<float>(velocity), 0.0f, currentNoteId)
    });

    noteOn = true;
  }

  size_t samplesLeft = static_cast<size_t>(numSamples);

  while (samplesLeft > 0) {
    size_t samplesToProcess = std::min(
      samplesLeft,
      durationSamples - currentNoteDuration
    );

    currentNoteDuration += samplesToProcess;
    samplesLeft -= samplesToProcess;

    if (currentNoteDuration >= durationSamples) {
      AnthemProcessorEvent noteOffEvent = {
        AnthemProcessorEventType::NoteOff
      };
      noteOffEvent.noteOff = NoteOffEvent(currentNote, 0, 0.0f, currentNoteId);

      midiOutBuffer->addEvent(noteOffEvent);

      currentNoteId++;
      currentNoteDuration = 0;

      currentNote += 2;

      if (currentNote > 80) {
        currentNote = 50;
      }

      AnthemProcessorEvent noteOnEvent = {
        AnthemProcessorEventType::NoteOn
      };
      noteOnEvent.noteOn = NoteOnEvent(currentNote, 0, static_cast<float>(velocity), 0.0f, currentNoteId);

      midiOutBuffer->addEvent(noteOnEvent);
    }
  }
}
