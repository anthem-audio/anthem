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

#include "modules/core/anthem.h"
#include "modules/processing_graph/compiler/anthem_node_process_context.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <optional>

SequenceNoteProviderProcessor::SequenceNoteProviderProcessor(
    const SequenceNoteProviderProcessorModelImpl& _impl)
  : AnthemProcessor("SequenceNoteProvider"), SequenceNoteProviderProcessorModelBase(_impl) {}

SequenceNoteProviderProcessor::~SequenceNoteProviderProcessor() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::rt_emitLiveNoteOffFromTrackedNote(
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    const TrackedNote& trackedNote,
    double sampleOffset) {
  targetBuffer->addEvent(AnthemLiveEvent{
      .sampleOffset = sampleOffset,
      .liveId = trackedNote.liveId,
      .event = AnthemEvent(AnthemNoteOffEvent(trackedNote.pitch, trackedNote.channel, 0.0f)),
  });
}

void SequenceNoteProviderProcessor::rt_emitLiveNoteOffsForAllTrackedNotes(
    std::unique_ptr<AnthemEventBuffer>& targetBuffer, double sampleOffset) {
  rt_activeSequenceNotes.rt_takeAll([&](const TrackedNote& trackedNote) {
    rt_emitLiveNoteOffFromTrackedNote(targetBuffer, trackedNote, sampleOffset);
  });
}

void SequenceNoteProviderProcessor::rt_handleSequenceNoteOn(
    AnthemNodeProcessContext& context,
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    AnthemSourceNoteId sourceId,
    const AnthemNoteOnEvent& noteOnEvent,
    double sampleOffset) {
  auto liveId = context.rt_allocateLiveNoteId();
  auto didTrackNote =
      rt_activeSequenceNotes.rt_add(sourceId, liveId, noteOnEvent.pitch, noteOnEvent.channel);

  targetBuffer->addEvent(AnthemLiveEvent{
      .sampleOffset = sampleOffset,
      .liveId = didTrackNote ? liveId : anthemInvalidLiveNoteId,
      .event = AnthemEvent(AnthemNoteOnEvent(
          noteOnEvent.pitch, noteOnEvent.channel, noteOnEvent.velocity, noteOnEvent.detune)),
  });
}

void SequenceNoteProviderProcessor::rt_handleSequenceNoteOff(
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    AnthemSourceNoteId sourceId,
    const AnthemNoteOffEvent& noteOffEvent,
    double sampleOffset) {
  auto trackedNote = rt_activeSequenceNotes.rt_takeByInputId(sourceId);
  if (trackedNote.has_value()) {
    rt_emitLiveNoteOffFromTrackedNote(targetBuffer, trackedNote.value(), sampleOffset);
    return;
  }

  targetBuffer->addEvent(AnthemLiveEvent{
      .sampleOffset = sampleOffset,
      .liveId = anthemInvalidLiveNoteId,
      .event = AnthemEvent(
          AnthemNoteOffEvent(noteOffEvent.pitch, noteOffEvent.channel, noteOffEvent.velocity)),
  });
}

void SequenceNoteProviderProcessor::rt_addEventsForJump(
    AnthemNodeProcessContext& context,
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    const PlayheadJumpEvent& event,
    double sampleTimeOffset) {
  auto& trackId = this->trackId();

  auto playEventsIter = event.eventsToPlayAtJump.find(trackId);
  if (playEventsIter != event.eventsToPlayAtJump.end()) {
    for (const auto& jumpEvent : playEventsIter->second) {
      if (jumpEvent.event.type == AnthemEventType::NoteOn) {
        rt_handleSequenceNoteOn(context,
                                targetBuffer,
                                jumpEvent.sequenceNoteId,
                                jumpEvent.event.noteOn,
                                sampleTimeOffset);
      }
    }
  }
}

void SequenceNoteProviderProcessor::prepareToProcess() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::process(AnthemNodeProcessContext& context, int numSamples) {
  auto& outputEventBuffer =
      context.getOutputEventBuffer(SequenceNoteProviderProcessorModelBase::eventOutputPortId);

  auto& trackId = this->trackId();

  auto& transport = Anthem::getInstance().transport;
  auto* config = transport->rt_config;

  if (transport->rt_shouldStopSequenceNotes) {
    rt_emitLiveNoteOffsForAllTrackedNotes(outputEventBuffer, 0.0);
  }

  if (transport->rt_playheadJumpEvent != nullptr) {
    rt_addEventsForJump(context, outputEventBuffer, *transport->rt_playheadJumpEvent);
  }

  if (!config->isPlaying) {
    return;
  }

  auto& sequenceStore = *Anthem::getInstance().sequenceStore;
  auto activeSequenceId = config->activeSequenceId;

  if (!activeSequenceId) {
    return;
  }

  auto& sequenceMap = sequenceStore.rt_getEventLists();
  if (sequenceMap.find(*activeSequenceId) == sequenceMap.end()) {
    return;
  }

  auto& eventsForSequence = sequenceMap.at(*activeSequenceId);

  int64_t sourceTrackId = trackId;
  if (config->activeTrackId.has_value() && config->activeTrackId.value() == trackId) {
    auto noTrackEventListIter = eventsForSequence.tracks->find(anthem_sequencer_track_ids::noTrack);
    if (noTrackEventListIter != eventsForSequence.tracks->end()) {
      sourceTrackId = anthem_sequencer_track_ids::noTrack;
    }
  }

  auto sourceTrackEventListIter = eventsForSequence.tracks->find(sourceTrackId);
  if (sourceTrackEventListIter == eventsForSequence.tracks->end()) {
    return;
  }

  auto& channelEvents = sourceTrackEventListIter->second;

  double playheadPos = transport->rt_playhead;
  auto timingParams = transport->rt_getTimingParams();

  if (channelEvents.invalidationOccurred) {
    rt_emitLiveNoteOffsForAllTrackedNotes(outputEventBuffer, 0.0);
  }

  double ticks =
      sequencer_timing::sampleCountToTickDelta(static_cast<double>(numSamples), timingParams);
  double sampleTimeOffset = 0.0;

  double incrementRemaining = ticks;
  double loopStart = config->loopStart;
  double loopEnd = config->loopEnd;

  while (incrementRemaining > 0.0) {
    double incrementAmount = incrementRemaining;
    bool didJump = false;

    double start = playheadPos;
    double end = -1;

    if (playheadPos + incrementAmount >= loopEnd) {
      incrementAmount = loopEnd - playheadPos;
      incrementRemaining -= incrementAmount;
      playheadPos = loopStart;
      end = loopEnd;
      didJump = true;
    } else {
      playheadPos += incrementAmount;
      end = playheadPos;
      incrementRemaining = 0.0;
    }

    if (incrementAmount < 0) {
      incrementAmount = 0;
    }

    double sampleAdvance = sequencer_timing::tickDeltaToSampleOffset(incrementAmount, timingParams);

    for (const auto& event : *channelEvents.events) {
      if (event.offset >= start && event.offset < end) {
        auto eventSampleOffset = sampleTimeOffset + sequencer_timing::tickDeltaToSampleOffset(
                                                        event.offset - start, timingParams);

        if (event.event.type == AnthemEventType::NoteOn) {
          rt_handleSequenceNoteOn(
              context, outputEventBuffer, event.sourceId, event.event.noteOn, eventSampleOffset);
        } else if (event.event.type == AnthemEventType::NoteOff) {
          rt_handleSequenceNoteOff(
              outputEventBuffer, event.sourceId, event.event.noteOff, eventSampleOffset);
        }
      }

      if (event.offset >= end) {
        break;
      }
    }

    if (didJump && config->playheadJumpEventForLoop.has_value()) {
      // Loop-stop behavior must be derived from the actual RT notes owned by
      // this provider. The loop-start payload may be slightly out of date, but
      // the active tracker is the authoritative source for what needs to stop.
      rt_emitLiveNoteOffsForAllTrackedNotes(outputEventBuffer, sampleTimeOffset + sampleAdvance);

      rt_addEventsForJump(context,
                          outputEventBuffer,
                          config->playheadJumpEventForLoop.value(),
                          sampleTimeOffset + sampleAdvance);
    }

    sampleTimeOffset += sampleAdvance;
  }
}
