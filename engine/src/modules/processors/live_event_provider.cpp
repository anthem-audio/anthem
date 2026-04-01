/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "live_event_provider.h"

#include "modules/processing_graph/compiler/anthem_node_process_context.h"

LiveEventProviderProcessor::LiveEventProviderProcessor(
  const LiveEventProviderProcessorModelImpl& _impl
) : AnthemProcessor("LiveEventProvider"),
    LiveEventProviderProcessorModelBase(_impl) {
  liveInputEventBuffer = std::make_unique<RingBuffer<AnthemLiveInputEvent, 4096>>();
}

LiveEventProviderProcessor::~LiveEventProviderProcessor() {
  // Nothing to do here
}

void LiveEventProviderProcessor::rt_emitLiveNoteOffFromTrackedNote(
  std::unique_ptr<AnthemEventBuffer>& targetBuffer,
  const TrackedNote& trackedNote,
  double sampleOffset
) {
  targetBuffer->addEvent(AnthemLiveEvent{
    .sampleOffset = sampleOffset,
    .liveId = trackedNote.liveId,
    .event = AnthemEvent(AnthemNoteOffEvent(
      trackedNote.pitch,
      trackedNote.channel,
      0.0f
    )),
  });
}

void LiveEventProviderProcessor::rt_handleLiveNoteOn(
  AnthemNodeProcessContext& context,
  std::unique_ptr<AnthemEventBuffer>& targetBuffer,
  AnthemLiveInputNoteId inputId,
  const AnthemNoteOnEvent& noteOnEvent,
  double sampleOffset
) {
  auto liveId = context.rt_allocateLiveNoteId();
  auto didTrackNote = rt_activeLiveNotes.rt_add(
    inputId,
    liveId,
    noteOnEvent.pitch,
    noteOnEvent.channel
  );

  targetBuffer->addEvent(AnthemLiveEvent{
    .sampleOffset = sampleOffset,
    .liveId = didTrackNote ? liveId : anthemInvalidLiveNoteId,
    .event = AnthemEvent(AnthemNoteOnEvent(
      noteOnEvent.pitch,
      noteOnEvent.channel,
      noteOnEvent.velocity,
      noteOnEvent.detune
    )),
  });
}

void LiveEventProviderProcessor::rt_handleLiveNoteOff(
  std::unique_ptr<AnthemEventBuffer>& targetBuffer,
  AnthemLiveInputNoteId inputId,
  const AnthemNoteOffEvent& noteOffEvent,
  double sampleOffset
) {
  auto trackedNote = rt_activeLiveNotes.rt_takeByInputId(inputId);
  if (trackedNote.has_value()) {
    rt_emitLiveNoteOffFromTrackedNote(
      targetBuffer,
      trackedNote.value(),
      sampleOffset
    );
    return;
  }

  targetBuffer->addEvent(AnthemLiveEvent{
    .sampleOffset = sampleOffset,
    .liveId = anthemInvalidLiveNoteId,
    .event = AnthemEvent(AnthemNoteOffEvent(
      noteOffEvent.pitch,
      noteOffEvent.channel,
      noteOffEvent.velocity
    )),
  });
}

void LiveEventProviderProcessor::rt_addLiveEventsToBuffer(
  AnthemNodeProcessContext& context,
  std::unique_ptr<AnthemEventBuffer>& targetBuffer
) {
  while (true) {
    auto eventOpt = liveInputEventBuffer->read();
    if (!eventOpt.has_value()) {
      return;
    }

    auto event = eventOpt.value();
    if (event.event.type == AnthemEventType::NoteOn) {
      rt_handleLiveNoteOn(
        context,
        targetBuffer,
        event.inputId,
        event.event.noteOn,
        event.sampleOffset
      );
    }
    else if (event.event.type == AnthemEventType::NoteOff) {
      rt_handleLiveNoteOff(
        targetBuffer,
        event.inputId,
        event.event.noteOff,
        event.sampleOffset
      );
    }
    else {
      targetBuffer->addEvent(AnthemLiveEvent{
        .sampleOffset = event.sampleOffset,
        .liveId = anthemInvalidLiveNoteId,
        .event = event.event,
      });
    }
  }
}

void LiveEventProviderProcessor::addLiveInputEvent(AnthemLiveInputEvent event) {
  liveInputEventBuffer->add(std::move(event));
}

void LiveEventProviderProcessor::prepareToProcess() {}

void LiveEventProviderProcessor::process(
  AnthemNodeProcessContext& context,
  int /*numSamples*/
) {
  auto& outputEventBuffer = context.getOutputEventBuffer(
    LiveEventProviderProcessorModelBase::eventOutputPortId
  );

  rt_addLiveEventsToBuffer(context, outputEventBuffer);
}
