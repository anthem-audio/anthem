/*
  Copyright (C) 2025 Joshua Wade

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

#include "sequence.h"

#include "modules/core/anthem.h"

void Sequence::initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) {
  SequenceModelBase::initialize(self, parent);

  // Write initial values to transport
  Anthem::getInstance().transport->ticksPerQuarter = this->ticksPerQuarter();
  Anthem::getInstance().transport->beatsPerMinute = this->beatsPerMinuteRaw() / 100.0;

  // This is temporary. We set the active sequence to the active arrangement
  // once, globally.
  //
  // We should in the future set the active arrangement to whatever was last
  // active in the UI.
  Anthem::getInstance().transport->activeSequenceId.set(this->activeArrangementID().value());

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
    Anthem::getInstance().transport->beatsPerMinute = beatsPerMinute;
  });
}
