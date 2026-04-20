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

#include "transport.h"

#include "modules/util/intentionally_leak.h"

#include <unordered_map>

namespace {
using TrackToJumpEventsMap = std::unordered_map<int64_t, std::vector<PlayheadJumpSequenceEvent>>;
using ActiveNotesForTrack = std::unordered_map<AnthemSourceNoteId, AnthemNoteOnEvent>;
using TrackToActiveNotesMap = std::unordered_map<int64_t, ActiveNotesForTrack>;

template <std::size_t queueSize, typename T>
// The audio thread uses this only for "old snapshot" objects that are already
// logically retired and just need to make it back to the main thread for
// deletion. If that bounded handoff queue overflows, we deliberately leak
// instead of doing non-real-time-safe cleanup here.
void enqueueForDeferredDeletionOrLeak(RingBuffer<T*, queueSize>& queue, T* ptr) {
  if (!queue.add(ptr)) {
    intentionallyLeak(ptr);
  }
}

template <std::size_t queueSize, typename T>
void deleteAllFromQueue(RingBuffer<T*, queueSize>& queue) {
  while (auto item = queue.read()) {
    delete item.value();
  }
}

template <typename Callback>
void forEachPlayableTrackEventList(const SequenceEventListCollection& sequence,
    std::optional<int64_t> activeTrackId,
    Callback&& callback) {
  auto noTrackIter = sequence.tracks.find(anthem_sequencer_track_ids::noTrack);
  if (noTrackIter != sequence.tracks.end()) {
    if (activeTrackId.has_value()) {
      callback(activeTrackId.value(), noTrackIter->second->events);
    }
    return;
  }

  for (auto& [trackId, eventList] : sequence.tracks) {
    callback(trackId, eventList->events);
  }
}

bool shouldApplySequenceEventToActiveNoteSnapshot(
    const AnthemSequenceEvent& sequenceEvent, double position) {
  if (sequenceEvent.offset < position) {
    return true;
  }

  if (sequenceEvent.offset > position) {
    return false;
  }

  // Events at the jump position are treated as ordered micro-steps:
  // boundary note-offs have already happened, boundary note-ons have not.
  //
  // We intentionally use the enum sort order here instead of `!= NoteOn`.
  // `NoteOff` is defined to sort before `NoteOn`, so only events ordered before
  // `NoteOn` should affect the "active at position" snapshot.
  return sequenceEvent.event.type < AnthemEventType::NoteOn;
}

ActiveNotesForTrack collectNotesActiveAtPositionForTrack(
    const std::vector<AnthemSequenceEvent>& events, double position) {
  auto activeNotes = ActiveNotesForTrack();

  for (const auto& sequenceEvent : events) {
    if (!shouldApplySequenceEventToActiveNoteSnapshot(sequenceEvent, position)) {
      break;
    }

    if (sequenceEvent.event.type == AnthemEventType::NoteOn) {
      activeNotes.insert_or_assign(sequenceEvent.sourceId, sequenceEvent.event.noteOn);
    } else if (sequenceEvent.event.type == AnthemEventType::NoteOff) {
      activeNotes.erase(sequenceEvent.sourceId);
    }
  }

  return activeNotes;
}

TrackToActiveNotesMap collectNotesActiveAtPositionForSequence(
    const SequenceEventListCollection& sequence,
    std::optional<int64_t> activeTrackId,
    double position) {
  auto collector = TrackToActiveNotesMap();

  forEachPlayableTrackEventList(sequence,
      activeTrackId,
      [&](int64_t destinationTrackId, const std::vector<AnthemSequenceEvent>& events) {
        auto activeNotes = collectNotesActiveAtPositionForTrack(events, position);
        if (!activeNotes.empty()) {
          collector.insert_or_assign(destinationTrackId, std::move(activeNotes));
        }
      });

  return collector;
}

void appendStartEvents(
    const TrackToActiveNotesMap& activeNotesByTrack, TrackToJumpEventsMap& collector) {
  for (const auto& [trackId, activeNotes] : activeNotesByTrack) {
    auto& events = collector[trackId];
    for (const auto& [sourceId, noteOn] : activeNotes) {
      events.push_back(PlayheadJumpSequenceEvent{
          .sequenceNoteId = sourceId,
          .event = AnthemEvent(noteOn),
      });
    }
  }
}
} // namespace

PlayheadJumpEvent buildPlayheadJumpEvent(const SequenceEventListCollection& sequence,
    std::optional<int64_t> activeTrackId,
    double playheadPosition) {
  auto event = PlayheadJumpEvent();
  event.newPlayheadPosition = playheadPosition;

  appendStartEvents(
      collectNotesActiveAtPositionForSequence(sequence, activeTrackId, playheadPosition),
      event.eventsToPlayAtJump);

  return event;
}

Transport::Transport(
    std::unique_ptr<TransportProjectView> projectView, std::unique_ptr<TransportClock> clock)
  : projectView(std::move(projectView)), clock(std::move(clock)), sampleRate{0.0}, rt_playhead{0.0},
    rt_sampleCounter{0} {
  jassert(this->projectView != nullptr);
  jassert(this->clock != nullptr);

  rt_config = new TransportConfig();

  sendConfigToAudioThread();

  rt_playheadJumpEvent = nullptr;
  rt_playheadJumpEventForSeek = nullptr;
  rt_playheadJumpEventForStart = nullptr;

  this->startTimer(100);
}

Transport::~Transport() {
  stopTimer();

  deleteAllFromQueue(configBuffer);
  deleteAllFromQueue(configDeleteBuffer);
  deleteAllFromQueue(playheadJumpEventBuffer);
  deleteAllFromQueue(playheadJumpEventDeleteBuffer);

  delete rt_playheadJumpEventForSeek;
  rt_playheadJumpEventForSeek = nullptr;
  rt_playheadJumpEventForStart = nullptr;
  rt_playheadJumpEvent = nullptr;

  delete rt_config;
  rt_config = nullptr;
}

void Transport::setIsPlaying(bool isPlaying) {
  config.isPlaying = isPlaying;
  sendConfigToAudioThread();
}

void Transport::setActiveSequenceId(const std::optional<int64_t>& sequenceId) {
  config.activeSequenceId = sequenceId;
  updateLoopPoints(false);
  updatePlayheadJumpEventForStart(false);
  sendConfigToAudioThread();
}

void Transport::setActiveTrackId(const std::optional<int64_t>& trackId) {
  config.activeTrackId = trackId;

  bool shouldRebuildJumpEvents = false;
  if (config.activeSequenceId.has_value()) {
    shouldRebuildJumpEvents = projectView->isPatternSequence(config.activeSequenceId.value());
  }

  if (shouldRebuildJumpEvents) {
    updateLoopPoints(false);
    updatePlayheadJumpEventForStart(false);
  }

  sendConfigToAudioThread();
}

void Transport::setTicksPerQuarter(int64_t ticksPerQuarter) {
  config.ticksPerQuarter = ticksPerQuarter;
  sendConfigToAudioThread();
}

void Transport::setBeatsPerMinute(double beatsPerMinute) {
  config.beatsPerMinute = beatsPerMinute;
  sendConfigToAudioThread();
}

void Transport::prepareToProcess() {
  sampleRate = clock->currentSampleRate();
  rt_sampleCounter = 0;
}

void Transport::rt_prepareForProcessingBlock() {
  rt_shouldStopSequenceNotes = false;

  auto newConfigOpt = configBuffer.read();

  while (true) {
    auto newerConfigOpt = configBuffer.read();
    if (newerConfigOpt.has_value()) {
      if (newConfigOpt.has_value()) {
        enqueueForDeferredDeletionOrLeak(configDeleteBuffer, *newConfigOpt);
      }
      newConfigOpt = newerConfigOpt;
    } else {
      break;
    }
  }

  if (newConfigOpt.has_value()) {
    auto* newConfig = newConfigOpt.value();

    if (!newConfig->isPlaying && rt_config->isPlaying) {
      rt_playhead = newConfig->playheadStart;
      rt_playheadJumpOrPauseOccurred = true;
      rt_shouldStopSequenceNotes = true;
    }

    if (newConfig->isPlaying && !rt_config->isPlaying) {
      rt_playheadJumpEventForStart = &newConfig->playheadJumpEventForStart;
    }

    enqueueForDeferredDeletionOrLeak(configDeleteBuffer, rt_config);
    rt_config = newConfig;
  }

  while (auto event = playheadJumpEventBuffer.read()) {
    if (rt_playheadJumpEventForSeek != nullptr) {
      enqueueForDeferredDeletionOrLeak(playheadJumpEventDeleteBuffer, rt_playheadJumpEventForSeek);
    }
    rt_playheadJumpEventForSeek = event.value();
  }

  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playhead = rt_playheadJumpEventForSeek->newPlayheadPosition;
    rt_playheadJumpOrPauseOccurred = true;
    rt_shouldStopSequenceNotes = true;
  }

  if (!rt_config->isPlaying) {
    if (rt_playheadJumpEventForSeek != nullptr) {
      enqueueForDeferredDeletionOrLeak(playheadJumpEventDeleteBuffer, rt_playheadJumpEventForSeek);
      rt_playheadJumpEventForSeek = nullptr;
    }
  }

  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playheadJumpEvent = rt_playheadJumpEventForSeek;
  } else if (rt_playheadJumpEventForStart != nullptr) {
    rt_playheadJumpEvent = rt_playheadJumpEventForStart;
  } else {
    rt_playheadJumpEvent = nullptr;
  }
}

void Transport::rt_advancePlayhead(int numSamples) {
  rt_playhead = rt_getPlayheadAfterAdvance(numSamples);
  rt_sampleCounter += static_cast<int64_t>(numSamples);
  rt_playheadJumpOrPauseOccurred = false;
  rt_shouldStopSequenceNotes = false;

  if (rt_playheadJumpEventForSeek != nullptr) {
    enqueueForDeferredDeletionOrLeak(playheadJumpEventDeleteBuffer, rt_playheadJumpEventForSeek);
    rt_playheadJumpEventForSeek = nullptr;
  }

  rt_playheadJumpEventForStart = nullptr;
}

double Transport::rt_getPlayheadAdvanceAmount(int numSamples) const {
  if (!rt_config->isPlaying) {
    return 0.0;
  }

  return sequencer_timing::sampleCountToTickDelta(
      static_cast<double>(numSamples), rt_getTimingParams());
}

sequencer_timing::TimingParams Transport::rt_getTimingParams() const {
  return sequencer_timing::TimingParams{
      .ticksPerQuarter = rt_config->ticksPerQuarter,
      .beatsPerMinute = rt_config->beatsPerMinute,
      .sampleRate = sampleRate,
  };
}

double Transport::rt_getPlayheadAfterAdvance(int numSamples) const {
  if (rt_config->isPlaying) {
    auto ticks = rt_getPlayheadAdvanceAmount(numSamples);
    return sequencer_timing::advancePlayheadByTickDelta(
        rt_playhead, ticks, rt_config->loopStart, rt_config->loopEnd);
  }

  return rt_playhead;
}

PlayheadJumpEvent Transport::createPlayheadJumpEvent(double playheadPosition) {
  auto event = PlayheadJumpEvent();
  event.newPlayheadPosition = playheadPosition;

  if (!config.activeSequenceId.has_value()) {
    return event;
  }

  const auto activeSequenceId = *config.activeSequenceId;
  auto* compiledSequence = projectView->compiledSequence(activeSequenceId);

  if (compiledSequence == nullptr) {
    return event;
  }

  return buildPlayheadJumpEvent(*compiledSequence, config.activeTrackId, playheadPosition);
}

void Transport::updatePlayheadJumpEventForStart(bool send) {
  config.playheadJumpEventForStart = createPlayheadJumpEvent(config.playheadStart);

  if (send) {
    sendConfigToAudioThread();
  }
}

void Transport::setPlayheadStart(double playheadStart) {
  auto event = createPlayheadJumpEvent(playheadStart);

  config.playheadStart = playheadStart;
  config.playheadJumpEventForStart = std::move(event);
  sendConfigToAudioThread();
}

void Transport::jumpTo(double playheadPosition) {
  if (config.hasLoop) {
    playheadPosition =
        sequencer_timing::wrapPlayheadToLoop(playheadPosition, config.loopStart, config.loopEnd);
  }

  auto event = createPlayheadJumpEvent(playheadPosition);
  auto eventPtr = new PlayheadJumpEvent(event);

  if (!playheadJumpEventBuffer.add(eventPtr)) {
    jassertfalse;
    delete eventPtr;
  }
}

void Transport::clearLoopPoints() {
  if (!config.hasLoop) {
    return;
  }

  config.hasLoop = false;
  config.loopStart = 0.0;
  config.loopEnd = std::numeric_limits<double>::infinity();
  config.playheadJumpEventForLoop = std::nullopt;
}

void Transport::updateLoopPoints(bool send) {
  if (!config.activeSequenceId.has_value()) {
    clearLoopPoints();

    if (send) {
      sendConfigToAudioThread();
    }

    return;
  }

  const auto activeSequenceId = *config.activeSequenceId;
  auto loopPoints = projectView->lookupLoopPoints(activeSequenceId);

  if (!loopPoints.has_value()) {
    clearLoopPoints();

    if (send) {
      sendConfigToAudioThread();
    }

    return;
  }

  config.hasLoop = true;
  config.loopStart = loopPoints->start;
  config.loopEnd = loopPoints->end;
  config.playheadJumpEventForLoop = createPlayheadJumpEvent(static_cast<double>(config.loopStart));

  if (send) {
    sendConfigToAudioThread();
  }
}

void Transport::timerCallback() {
  while (auto event = playheadJumpEventDeleteBuffer.read()) {
    delete event.value();
  }

  while (auto pendingConfig = configDeleteBuffer.read()) {
    delete pendingConfig.value();
  }
}

void Transport::sendConfigToAudioThread() {
  TransportConfig* configCopy = new TransportConfig(config);
  if (!configBuffer.add(configCopy)) {
    jassertfalse;
    delete configCopy;
  }
}
