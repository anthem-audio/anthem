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

#include <unordered_map>

#include "modules/core/anthem.h"

namespace {
using TrackToJumpEventsMap =
  std::unordered_map<int64_t, std::vector<PlayheadJumpSequenceEvent>>;
using ActiveNotesForTrack = std::unordered_map<AnthemSourceNoteId, AnthemNoteOnEvent>;
using TrackToActiveNotesMap = std::unordered_map<int64_t, ActiveNotesForTrack>;

template <typename Callback>
void forEachPlayableTrackEventList(
  const SequenceEventListCollection& sequence,
  std::optional<int64_t> activeTrackId,
  Callback&& callback
) {
  auto noTrackIter = sequence.tracks->find(anthem_sequencer_track_ids::noTrack);
  if (noTrackIter != sequence.tracks->end()) {
    if (activeTrackId.has_value()) {
      callback(activeTrackId.value(), *noTrackIter->second.events);
    }
    return;
  }

  for (auto& [trackId, eventList] : *sequence.tracks) {
    callback(trackId, *eventList.events);
  }
}

bool shouldApplySequenceEventToActiveNoteSnapshot(
  const AnthemSequenceEvent& sequenceEvent,
  double position
) {
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
  const std::vector<AnthemSequenceEvent>& events,
  double position
) {
  auto activeNotes = ActiveNotesForTrack();

  for (const auto& sequenceEvent : events) {
    if (!shouldApplySequenceEventToActiveNoteSnapshot(sequenceEvent, position)) {
      break;
    }

    if (sequenceEvent.event.type == AnthemEventType::NoteOn) {
      activeNotes.insert_or_assign(
        sequenceEvent.sourceId,
        sequenceEvent.event.noteOn
      );
    }
    else if (sequenceEvent.event.type == AnthemEventType::NoteOff) {
      activeNotes.erase(sequenceEvent.sourceId);
    }
  }

  return activeNotes;
}

TrackToActiveNotesMap collectNotesActiveAtPositionForSequence(
  const SequenceEventListCollection& sequence,
  std::optional<int64_t> activeTrackId,
  double position
) {
  auto collector = TrackToActiveNotesMap();

  forEachPlayableTrackEventList(
    sequence,
    activeTrackId,
    [&](int64_t destinationTrackId, const std::vector<AnthemSequenceEvent>& events) {
      auto activeNotes = collectNotesActiveAtPositionForTrack(events, position);
      if (!activeNotes.empty()) {
        collector.insert_or_assign(destinationTrackId, std::move(activeNotes));
      }
    }
  );

  return collector;
}

void appendStartEvents(
  const TrackToActiveNotesMap& activeNotesByTrack,
  TrackToJumpEventsMap& collector
) {
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

PlayheadJumpEvent buildPlayheadJumpEvent(
  const SequenceEventListCollection& sequence,
  std::optional<int64_t> activeTrackId,
  double playheadPosition
) {
  auto event = PlayheadJumpEvent();
  event.newPlayheadPosition = playheadPosition;

  appendStartEvents(
    collectNotesActiveAtPositionForSequence(
      sequence,
      activeTrackId,
      playheadPosition
    ),
    event.eventsToPlayAtJump
  );

  return event;
}

Transport::Transport() : rt_playhead{0.0}, rt_sampleCounter{0} {
  rt_config = new TransportConfig();

  sendConfigToAudioThread();

  rt_playheadJumpEvent = nullptr;
  rt_playheadJumpEventForSeek = nullptr;
  rt_playheadJumpEventForStart = nullptr;

  this->startTimer(100);
}

void Transport::setIsPlaying(bool isPlaying) {
  config.isPlaying = isPlaying;
  sendConfigToAudioThread();
}

void Transport::setActiveSequenceId(std::optional<int64_t>& sequenceId) {
  config.activeSequenceId = sequenceId;
  updateLoopPoints(false);
  updatePlayheadJumpEventForStart(false);
  sendConfigToAudioThread();
}

void Transport::setActiveTrackId(std::optional<int64_t>& trackId) {
  config.activeTrackId = trackId;

  bool shouldRebuildJumpEvents = false;
  if (config.activeSequenceId.has_value()) {
    auto& patterns = *Anthem::getInstance().project->sequence()->patterns();
    shouldRebuildJumpEvents =
      patterns.find(config.activeSequenceId.value()) != patterns.end();
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
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);
  sampleRate = currentDevice->getCurrentSampleRate();

  rt_sampleCounter = 0;
}

void Transport::rt_prepareForProcessingBlock() {
  rt_shouldStopSequenceNotes = false;

  auto newConfigOpt = configBuffer.read();

  while (true) {
    auto newerConfigOpt = configBuffer.read();
    if (newerConfigOpt.has_value()) {
      configDeleteBuffer.add(newConfigOpt.value());
      newConfigOpt = newerConfigOpt;
    }
    else {
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

    configDeleteBuffer.add(rt_config);
    rt_config = newConfig;
  }

  while (auto event = playheadJumpEventBuffer.read()) {
    if (rt_playheadJumpEventForSeek != nullptr) {
      playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    }
    rt_playheadJumpEventForSeek = event.value();
  }

  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playhead = rt_playheadJumpEventForSeek->newPlayheadPosition;
    rt_playheadJumpOrPauseOccurred = true;
    rt_shouldStopSequenceNotes = true;
  }

  if (!rt_config->isPlaying) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    rt_playheadJumpEventForSeek = nullptr;
  }

  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playheadJumpEvent = rt_playheadJumpEventForSeek;
  }
  else if (rt_playheadJumpEventForStart != nullptr) {
    rt_playheadJumpEvent = rt_playheadJumpEventForStart;
  }
  else {
    rt_playheadJumpEvent = nullptr;
  }
}

void Transport::rt_advancePlayhead(int numSamples) {
  rt_playhead = rt_getPlayheadAfterAdvance(numSamples);
  rt_sampleCounter += static_cast<int64_t>(numSamples);
  rt_playheadJumpOrPauseOccurred = false;
  rt_shouldStopSequenceNotes = false;

  if (rt_playheadJumpEventForSeek != nullptr) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    rt_playheadJumpEventForSeek = nullptr;
  }

  rt_playheadJumpEventForStart = nullptr;
}

double Transport::rt_getPlayheadAdvanceAmount(int numSamples) const {
  if (!rt_config->isPlaying) {
    return 0.0;
  }

  return sequencer_timing::sampleCountToTickDelta(
    static_cast<double>(numSamples),
    rt_getTimingParams()
  );
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
      rt_playhead,
      ticks,
      rt_config->loopStart,
      rt_config->loopEnd
    );
  }

  return rt_playhead;
}

PlayheadJumpEvent Transport::createPlayheadJumpEvent(double playheadPosition) {
  auto event = PlayheadJumpEvent();
  event.newPlayheadPosition = playheadPosition;

  if (!config.activeSequenceId.has_value()) {
    return event;
  }

  auto* compiledSequence =
    Anthem::getInstance().sequenceStore->getSequenceEventList(
      config.activeSequenceId.value()
    );

  if (compiledSequence == nullptr) {
    return event;
  }

  return buildPlayheadJumpEvent(
    *compiledSequence,
    config.activeTrackId,
    playheadPosition
  );
}

void Transport::updatePlayheadJumpEventForStart(bool send) {
  if (!config.activeSequenceId.has_value()) {
    return;
  }

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
    playheadPosition = sequencer_timing::wrapPlayheadToLoop(
      playheadPosition,
      config.loopStart,
      config.loopEnd
    );
  }

  auto event = createPlayheadJumpEvent(playheadPosition);
  auto eventPtr = new PlayheadJumpEvent(event);

  playheadJumpEventBuffer.add(eventPtr);
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

  auto& patterns = *Anthem::getInstance().project->sequence()->patterns();
  auto& arrangements = *Anthem::getInstance().project->sequence()->arrangements();

  std::shared_ptr<LoopPointsModel> loopPoints;

  if (patterns.find(config.activeSequenceId.value()) != patterns.end() &&
      patterns.at(config.activeSequenceId.value())->loopPoints().has_value()) {
    loopPoints = patterns.at(config.activeSequenceId.value())->loopPoints().value();
  }
  else if (arrangements.find(config.activeSequenceId.value()) != arrangements.end() &&
      arrangements.at(config.activeSequenceId.value())->loopPoints().has_value()) {
    loopPoints = arrangements.at(config.activeSequenceId.value())->loopPoints().value();
  }
  else {
    clearLoopPoints();

    if (send) {
      sendConfigToAudioThread();
    }

    return;
  }

  config.hasLoop = true;
  config.loopStart = static_cast<double>(loopPoints->start());
  config.loopEnd = static_cast<double>(loopPoints->end());
  config.playheadJumpEventForLoop = createPlayheadJumpEvent(
    static_cast<double>(config.loopStart)
  );

  sendConfigToAudioThread();
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
  configBuffer.add(configCopy);
}
