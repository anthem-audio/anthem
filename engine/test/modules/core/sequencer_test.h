/*
  Copyright (C) 2026 Joshua Wade

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

#include "modules/core/anthem.h"
#include "modules/core/sequencer.h"

#include <juce_core/juce_core.h>

class SequencerTest : public juce::UnitTest {
  static constexpr int64_t restoredPlayheadPosition = 96;

  static std::shared_ptr<Sequencer> createSequencer() {
    auto defaultTimeSignature = std::make_shared<TimeSignatureModel>(TimeSignatureModelImpl{
        .numerator = 4,
        .denominator = 4,
    });

    auto sequencer = std::make_shared<Sequencer>(SequencerModelImpl{
        .ticksPerQuarter = 96,
        .beatsPerMinuteRaw = 12000,
        .patterns =
            std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<PatternModel>>>(),
        .activePatternID = std::nullopt,
        .activeTrackID = std::nullopt,
        .arrangements =
            std::make_shared<AnthemModelUnorderedMap<int64_t, std::shared_ptr<ArrangementModel>>>(),
        .arrangementOrder = std::make_shared<AnthemModelVector<int64_t>>(),
        .activeArrangementID = std::nullopt,
        .activeTransportSequenceID = std::nullopt,
        .defaultTimeSignature = defaultTimeSignature,
        .playbackStartPosition = restoredPlayheadPosition,
        .isPlaying = false,
    });

    return sequencer;
  }
public:
  SequencerTest() : juce::UnitTest("SequencerTest", "Anthem") {}

  void runTest() override {
    testInitializeRestoresPlaybackStartPositionForStop();
  }

  void testInitializeRestoresPlaybackStartPositionForStop() {
    beginTest("Sequencer initialization restores the stop target from playbackStartPosition");

    Anthem::cleanup();

    {
      auto& anthem = Anthem::getInstance();
      anthem.transport = std::make_unique<Transport>();

      auto sequencer = createSequencer();
      sequencer->initialize(sequencer, std::shared_ptr<AnthemModelBase>());

      anthem.transport->rt_prepareForProcessingBlock();
      expectEquals(anthem.transport->config.playheadStart,
                   static_cast<double>(restoredPlayheadPosition),
                   "Startup should restore the transport stop target.");
      expectEquals(anthem.transport->rt_playhead,
                   static_cast<double>(restoredPlayheadPosition),
                   "Startup should restore the stopped playhead position.");

      anthem.transport->setIsPlaying(true);
      anthem.transport->rt_prepareForProcessingBlock();

      anthem.transport->setIsPlaying(false);
      anthem.transport->rt_prepareForProcessingBlock();

      expectEquals(
          anthem.transport->rt_playhead,
          static_cast<double>(restoredPlayheadPosition),
          "After play then stop, the playhead should return to the restored startup position.");
    }

    Anthem::cleanup();
  }
};

static SequencerTest sequencerTest;
