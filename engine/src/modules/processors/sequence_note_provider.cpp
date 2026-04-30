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

#include "sequence_note_provider.h"

#include "modules/core/engine.h"
#include "modules/processing_graph/runtime/node_process_context.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

namespace anthem {

SequenceNoteProviderProcessor::SequenceNoteProviderProcessor(
    const SequenceNoteProviderProcessorModelImpl& _impl)
  : Processor("SequenceNoteProvider"), SequenceNoteProviderProcessorModelBase(_impl) {}

SequenceNoteProviderProcessor::~SequenceNoteProviderProcessor() {
  // Nothing to do here
}

const SequenceEventList* SequenceNoteProviderProcessor::rt_getSourceTrackEvents(
    const RuntimeDependencies& dependencies, int64_t trackId) {
  if (dependencies.rt_activeSequence == nullptr) {
    return nullptr;
  }

  int64_t sourceTrackId = trackId;
  if (dependencies.rt_activeTrackId.has_value() &&
      dependencies.rt_activeTrackId.value() == trackId) {
    auto noTrackEventListIter =
        dependencies.rt_activeSequence->tracks.find(sequencer_track_ids::noTrack);
    if (noTrackEventListIter != dependencies.rt_activeSequence->tracks.end()) {
      sourceTrackId = sequencer_track_ids::noTrack;
    }
  }

  auto sourceTrackEventListIter = dependencies.rt_activeSequence->tracks.find(sourceTrackId);
  if (sourceTrackEventListIter == dependencies.rt_activeSequence->tracks.end()) {
    return nullptr;
  }

  return sourceTrackEventListIter->second;
}

void SequenceNoteProviderProcessor::rt_emitLiveNoteOffFromTrackedNote(
    EventBuffer& targetBuffer, const TrackedNote& trackedNote, int sampleOffset) {
  targetBuffer.addEvent(LiveEvent{
      .sampleOffset = sampleOffset,
      .liveId = trackedNote.liveId,
      .event = Event(NoteOffEvent(trackedNote.pitch, trackedNote.channel, 0.0f)),
  });
}

void SequenceNoteProviderProcessor::rt_emitLiveNoteOffsForAllTrackedNotes(
    RuntimeState& state, EventBuffer& targetBuffer, int sampleOffset) {
  state.rt_activeSequenceNotes.rt_takeAll([&](const TrackedNote& trackedNote) {
    rt_emitLiveNoteOffFromTrackedNote(targetBuffer, trackedNote, sampleOffset);
  });
}

void SequenceNoteProviderProcessor::rt_handleSequenceNoteOff(RuntimeState& state,
    EventBuffer& targetBuffer,
    SourceNoteId sourceId,
    const NoteOffEvent& noteOffEvent,
    int sampleOffset) {
  auto trackedNote = state.rt_activeSequenceNotes.rt_takeByInputId(sourceId);
  if (trackedNote.has_value()) {
    rt_emitLiveNoteOffFromTrackedNote(targetBuffer, trackedNote.value(), sampleOffset);
    return;
  }

  targetBuffer.addEvent(LiveEvent{
      .sampleOffset = sampleOffset,
      .liveId = invalidLiveNoteId,
      .event = Event(NoteOffEvent(noteOffEvent.pitch, noteOffEvent.channel, noteOffEvent.velocity)),
  });
}

void SequenceNoteProviderProcessor::prepareToProcess() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::process(NodeProcessContext& context, int numSamples) {
  auto& outputEventBuffer =
      context.getOutputEventBuffer(SequenceNoteProviderProcessorModelBase::eventOutputPortId);

  auto& trackId = this->trackId();
  auto& transport = Engine::getInstance().transport;
  const auto* config = transport->rt_config;
  auto& sequenceStore = *Engine::getInstance().sequenceStore;

  const SequenceEventListCollection* activeSequence = nullptr;
  if (config->activeSequenceId.has_value()) {
    auto& sequenceSnapshot = sequenceStore.rt_getEventLists();
    auto activeSequenceIter = sequenceSnapshot.sequences.find(*config->activeSequenceId);
    if (activeSequenceIter != sequenceSnapshot.sequences.end()) {
      activeSequence = activeSequenceIter->second;
    }
  }

  RuntimeDependencies dependencies{
      .rt_shouldStopSequenceNotes = transport->rt_shouldStopSequenceNotes,
      .rt_playheadJumpEvent = transport->rt_playheadJumpEvent,
      .rt_isPlaying = config->isPlaying,
      .rt_activeTrackId = config->activeTrackId,
      .rt_playhead = transport->rt_playhead,
      .rt_loopStart = config->loopStart,
      .rt_loopEnd = config->loopEnd,
      .rt_playheadJumpEventForLoop = config->playheadJumpEventForLoop.has_value()
                                         ? &config->playheadJumpEventForLoop.value()
                                         : nullptr,
      .rt_timingParams = transport->rt_getTimingParams(),
      .rt_activeSequence = activeSequence,
  };

  rt_processBlock(rt_state, dependencies, *outputEventBuffer, trackId, numSamples, [&context]() {
    return context.rt_allocateLiveNoteId();
  });
}

} // namespace anthem
