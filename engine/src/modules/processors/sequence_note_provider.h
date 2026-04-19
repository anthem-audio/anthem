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

#pragma once

#include "generated/lib/model/processing_graph/processors/sequence_note_provider.h"
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processors/note_tracker.h"
#include "modules/sequencer/events/event.h"
#include "modules/sequencer/runtime/transport.h"

#include <concepts>
#include <type_traits>

class AnthemNodeProcessContext;

template <typename T>
concept SequenceNoteLiveIdAllocator =
    std::invocable<T&> && std::convertible_to<std::invoke_result_t<T&>, AnthemLiveNoteId>;

// This processor is a bridge between the sequencer and the node graph. It's a
// special node that the sequencer can use to send notes from the sequence to the
// node graph as note events.
//
// If this node's track ID matches the transport's active track ID, the node may
// read from the reserved track-less sequence event list instead of the
// per-track list.
class SequenceNoteProviderProcessor : public AnthemProcessor,
                                      public SequenceNoteProviderProcessorModelBase {
private:
  static constexpr size_t rt_maxTrackedSequenceNotes = 256;
  friend class SequenceNoteProviderTest;

  struct RuntimeState {
    NoteTracker<rt_maxTrackedSequenceNotes> rt_activeSequenceNotes;
  };

  struct RuntimeDependencies {
    bool rt_shouldStopSequenceNotes = false;
    const PlayheadJumpEvent* rt_playheadJumpEvent = nullptr;

    bool rt_isPlaying = false;
    std::optional<int64_t> rt_activeTrackId;
    double rt_playhead = 0.0;
    double rt_loopStart = 0.0;
    double rt_loopEnd = std::numeric_limits<double>::infinity();
    const PlayheadJumpEvent* rt_playheadJumpEventForLoop = nullptr;

    sequencer_timing::TimingParams rt_timingParams{};
    const SequenceEventListCollection* rt_activeSequence = nullptr;
  };

  RuntimeState rt_state;

  static const SequenceEventList* rt_getSourceTrackEvents(
      const RuntimeDependencies& dependencies, int64_t trackId);

  static void rt_emitLiveNoteOffFromTrackedNote(
      AnthemEventBuffer& targetBuffer, const TrackedNote& trackedNote, double sampleOffset);
  static void rt_emitLiveNoteOffsForAllTrackedNotes(
      RuntimeState& state, AnthemEventBuffer& targetBuffer, double sampleOffset);
  static void rt_handleSequenceNoteOff(RuntimeState& state,
      AnthemEventBuffer& targetBuffer,
      AnthemSourceNoteId sourceId,
      const AnthemNoteOffEvent& noteOffEvent,
      double sampleOffset);

  template <SequenceNoteLiveIdAllocator LiveNoteIdAllocator>
  static void rt_handleSequenceNoteOn(RuntimeState& state,
      AnthemEventBuffer& targetBuffer,
      LiveNoteIdAllocator&& liveNoteIdAllocator,
      AnthemSourceNoteId sourceId,
      const AnthemNoteOnEvent& noteOnEvent,
      double sampleOffset) {
    AnthemLiveNoteId liveId = liveNoteIdAllocator();
    auto didTrackNote = state.rt_activeSequenceNotes.rt_add(
        sourceId, liveId, noteOnEvent.pitch, noteOnEvent.channel);

    targetBuffer.addEvent(AnthemLiveEvent{
        .sampleOffset = sampleOffset,
        .liveId = didTrackNote ? liveId : anthemInvalidLiveNoteId,
        .event = AnthemEvent(AnthemNoteOnEvent(
            noteOnEvent.pitch, noteOnEvent.channel, noteOnEvent.velocity, noteOnEvent.detune)),
    });
  }

  template <SequenceNoteLiveIdAllocator LiveNoteIdAllocator>
  static void rt_addEventsForJump(RuntimeState& state,
      AnthemEventBuffer& targetBuffer,
      int64_t trackId,
      const PlayheadJumpEvent& event,
      LiveNoteIdAllocator&& liveNoteIdAllocator,
      double sampleTimeOffset = 0.0) {
    auto playEventsIter = event.eventsToPlayAtJump.find(trackId);
    if (playEventsIter == event.eventsToPlayAtJump.end()) {
      return;
    }

    for (const auto& jumpEvent : playEventsIter->second) {
      if (jumpEvent.event.type == AnthemEventType::NoteOn) {
        rt_handleSequenceNoteOn(state,
            targetBuffer,
            liveNoteIdAllocator,
            jumpEvent.sequenceNoteId,
            jumpEvent.event.noteOn,
            sampleTimeOffset);
      }
    }
  }

  template <SequenceNoteLiveIdAllocator LiveNoteIdAllocator>
  static void rt_processBlock(RuntimeState& state,
      const RuntimeDependencies& dependencies,
      AnthemEventBuffer& targetBuffer,
      int64_t trackId,
      int numSamples,
      LiveNoteIdAllocator&& liveNoteIdAllocator) {
    if (dependencies.rt_shouldStopSequenceNotes) {
      rt_emitLiveNoteOffsForAllTrackedNotes(state, targetBuffer, 0.0);
    }

    if (dependencies.rt_playheadJumpEvent != nullptr) {
      rt_addEventsForJump(
          state, targetBuffer, trackId, *dependencies.rt_playheadJumpEvent, liveNoteIdAllocator);
    }

    if (!dependencies.rt_isPlaying) {
      return;
    }

    auto* channelEvents = rt_getSourceTrackEvents(dependencies, trackId);
    if (channelEvents == nullptr) {
      return;
    }

    double playheadPos = dependencies.rt_playhead;

    if (channelEvents->rt_invalidationOccurred) {
      rt_emitLiveNoteOffsForAllTrackedNotes(state, targetBuffer, 0.0);
    }

    double ticks = sequencer_timing::sampleCountToTickDelta(
        static_cast<double>(numSamples), dependencies.rt_timingParams);
    double sampleTimeOffset = 0.0;

    double incrementRemaining = ticks;

    while (incrementRemaining > 0.0) {
      double incrementAmount = incrementRemaining;
      bool didJump = false;

      double start = playheadPos;
      double end = -1.0;

      if (playheadPos + incrementAmount >= dependencies.rt_loopEnd) {
        incrementAmount = dependencies.rt_loopEnd - playheadPos;
        incrementRemaining -= incrementAmount;
        playheadPos = dependencies.rt_loopStart;
        end = dependencies.rt_loopEnd;
        didJump = true;
      } else {
        playheadPos += incrementAmount;
        end = playheadPos;
        incrementRemaining = 0.0;
      }

      if (incrementAmount < 0.0) {
        incrementAmount = 0.0;
      }

      double sampleAdvance =
          sequencer_timing::tickDeltaToSampleOffset(incrementAmount, dependencies.rt_timingParams);

      for (const auto& event : channelEvents->events) {
        if (event.offset >= start && event.offset < end) {
          auto eventSampleOffset =
              sampleTimeOffset + sequencer_timing::tickDeltaToSampleOffset(
                                     event.offset - start, dependencies.rt_timingParams);

          if (event.event.type == AnthemEventType::NoteOn) {
            rt_handleSequenceNoteOn(state,
                targetBuffer,
                liveNoteIdAllocator,
                event.sourceId,
                event.event.noteOn,
                eventSampleOffset);
          } else if (event.event.type == AnthemEventType::NoteOff) {
            rt_handleSequenceNoteOff(
                state, targetBuffer, event.sourceId, event.event.noteOff, eventSampleOffset);
          }
        }

        if (event.offset >= end) {
          break;
        }
      }

      if (didJump && dependencies.rt_playheadJumpEventForLoop != nullptr) {
        // Loop-stop behavior must be derived from the actual RT notes owned by
        // this provider. The loop-start payload may be slightly out of date, but
        // the active tracker is the authoritative source for what needs to stop.
        rt_emitLiveNoteOffsForAllTrackedNotes(
            state, targetBuffer, sampleTimeOffset + sampleAdvance);

        rt_addEventsForJump(state,
            targetBuffer,
            trackId,
            *dependencies.rt_playheadJumpEventForLoop,
            liveNoteIdAllocator,
            sampleTimeOffset + sampleAdvance);
      }

      sampleTimeOffset += sampleAdvance;
    }
  }
public:
  SequenceNoteProviderProcessor(const SequenceNoteProviderProcessorModelImpl& _impl);
  ~SequenceNoteProviderProcessor() override;

  SequenceNoteProviderProcessor(const SequenceNoteProviderProcessor&) = delete;
  SequenceNoteProviderProcessor& operator=(const SequenceNoteProviderProcessor&) = delete;

  SequenceNoteProviderProcessor(SequenceNoteProviderProcessor&&) noexcept = default;
  SequenceNoteProviderProcessor& operator=(SequenceNoteProviderProcessor&&) noexcept = default;

  int getOutputPortIndex() {
    return 0;
  }

  void prepareToProcess() override;
  void process(AnthemNodeProcessContext& context, int numSamples) override;
};
