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

#include "sequencer.h"

#include "modules/core/anthem.h"

void Sequencer::initialize(std::shared_ptr<AnthemModelBase> selfModel,
                           std::shared_ptr<AnthemModelBase> parentModel) {
  auto& transport = *Anthem::getInstance().transport;

  // Write initial values to transport
  transport.setTicksPerQuarter(this->ticksPerQuarter());
  transport.setBeatsPerMinute(this->beatsPerMinuteRaw() / 100.0);
  transport.setActiveSequenceId(this->activeTransportSequenceID());
  transport.setActiveTrackId(this->activeTrackID());
  transport.setIsPlaying(this->isPlaying());
  transport.setPlayheadStart(static_cast<double>(this->playbackStartPosition()));

  transport.jumpTo(static_cast<double>(this->playbackStartPosition()));

  addBeatsPerMinuteRawObserver([this](int64_t value) {
    auto beatsPerMinute = static_cast<double>(value) / 100.0;

    // The Transport class acts as the source of truth for real-time code with
    // respect to the playhead position and tempo. The real-time code can't
    // access the project model, since the project model is not thread-safe and
    // trying to gate access from the real-time thread with mutexes would make
    // the real-time code non-realtime.
    //
    // So, we need to update the Transport class whenever the project BPM
    // changes.
    //
    // So far this completely ignores tempo automation, so we'll need to address
    // that at some point.
    Anthem::getInstance().transport->setBeatsPerMinute(beatsPerMinute);
  });

  addActiveTransportSequenceIDObserver([this](std::optional<int64_t> value) {
    Anthem::getInstance().transport->setActiveSequenceId(value);
  });

  addActiveTrackIDObserver([this](std::optional<int64_t> value) {
    Anthem::getInstance().transport->setActiveTrackId(value);
  });

  addIsPlayingObserver(
      [this](bool value) { Anthem::getInstance().transport->setIsPlaying(value); });

  addPlaybackStartPositionObserver(
      [this](double value) { Anthem::getInstance().transport->setPlayheadStart(value); });

  SequencerModelBase::initialize(selfModel, parentModel);
}
