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

#include "modules/core/engine.h"
#include "modules/sequencer/compiler/automation_sequence_compiler.h"

#include <cmath>
#include <initializer_list>
#include <limits>

namespace anthem {

class AutomationSequenceCompilerTest : public juce::UnitTest {
  static constexpr EntityId pattern1Id = 101;
  static constexpr EntityId pattern2Id = 102;
  static constexpr EntityId arrangementId = 201;
  static constexpr EntityId track1Id = 301;
  static constexpr EntityId clip1Id = 401;
  static constexpr EntityId clip2Id = 402;
  static constexpr EntityId point1Id = 501;
  static constexpr EntityId point2Id = 502;
  static constexpr EntityId point3Id = 503;
  static constexpr EntityId point4Id = 504;

  static bool nearlyEqual(double left, double right) {
    return std::fabs(left - right) < 0.0001;
  }

  static std::shared_ptr<AutomationPointModel> makePoint(
      EntityId id, int64_t offset, double value) {
    return std::make_shared<AutomationPointModel>(AutomationPointModelImpl{
        .id = id,
        .offset = offset,
        .value = value,
        .tension = 0.0,
        .curve = AutomationCurveType::smooth,
    });
  }

  static std::shared_ptr<PatternModel> makePattern(
      EntityId id, std::initializer_list<std::shared_ptr<AutomationPointModel>> points) {
    auto pointList = std::make_shared<ModelVector<std::shared_ptr<AutomationPointModel>>>();
    for (const auto& point : points) {
      pointList->push_back(point);
    }

    return std::make_shared<PatternModel>(PatternModelImpl{
        .id = id,
        .name = "Pattern",
        .notes = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<NoteModel>>>(),
        .automation = std::make_shared<AutomationLaneModel>(AutomationLaneModelImpl{
            .points = pointList,
        }),
        .timeSignatureChanges =
            std::make_shared<ModelVector<std::shared_ptr<TimeSignatureChangeModel>>>(),
        .loopPoints = std::nullopt,
    });
  }

  static std::shared_ptr<ClipModel> makeClip(EntityId id,
      EntityId patternId,
      EntityId trackId,
      int64_t offset,
      std::optional<std::tuple<int64_t, int64_t>> timeView = std::nullopt) {
    std::optional<std::shared_ptr<TimeViewModel>> timeViewModel = std::nullopt;
    if (timeView.has_value()) {
      timeViewModel = std::make_shared<TimeViewModel>(TimeViewModelImpl{
          .start = std::get<0>(timeView.value()),
          .end = std::get<1>(timeView.value()),
      });
    }

    return std::make_shared<ClipModel>(ClipModelImpl{
        .id = id,
        .timeView = timeViewModel,
        .patternId = patternId,
        .trackId = trackId,
        .offset = offset,
    });
  }

  static std::shared_ptr<ArrangementModel> makeArrangement(
      std::initializer_list<std::shared_ptr<ClipModel>> clips) {
    auto clipMap = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<ClipModel>>>();
    for (const auto& clip : clips) {
      clipMap->insert_or_assign(clip->id(), clip);
    }

    return std::make_shared<ArrangementModel>(ArrangementModelImpl{
        .id = arrangementId,
        .name = "Arrangement",
        .clips = clipMap,
        .timeSignatureChanges =
            std::make_shared<ModelVector<std::shared_ptr<TimeSignatureChangeModel>>>(),
        .loopPoints = std::nullopt,
    });
  }

  static std::shared_ptr<Sequencer> makeSequencer(
      std::initializer_list<std::shared_ptr<PatternModel>> patterns,
      std::shared_ptr<ArrangementModel> arrangement) {
    auto patternMap = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<PatternModel>>>();

    for (const auto& pattern : patterns) {
      patternMap->insert_or_assign(pattern->id(), pattern);
    }

    if (arrangement == nullptr) {
      arrangement = makeArrangement({});
    }

    return std::make_shared<Sequencer>(SequencerModelImpl{
        .ticksPerQuarter = 96,
        .beatsPerMinuteRaw = 12000,
        .patterns = patternMap,
        .activePatternID = std::nullopt,
        .activeTrackID = std::nullopt,
        .arrangement = arrangement,
        .activeTransportSequenceID = std::nullopt,
        .defaultTimeSignature = std::make_shared<TimeSignatureModel>(TimeSignatureModelImpl{
            .numerator = 4,
            .denominator = 4,
        }),
        .playbackStartPosition = 0,
        .isPlaying = false,
    });
  }

  static void installProject(std::initializer_list<std::shared_ptr<PatternModel>> patterns,
      std::shared_ptr<ArrangementModel> arrangement) {
    Engine::cleanup();

    auto& engine = Engine::getInstance();
    engine.automationSequenceStore = std::make_unique<RuntimeAutomationSequenceStore>();
    engine.project = std::make_shared<Project>(ProjectModelImpl{
        .sequence = makeSequencer(patterns, arrangement),
        .processingGraph = nullptr,
        .masterOutputNodeId = std::nullopt,
        .tracks = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<TrackModel>>>(),
        .trackOrder = std::make_shared<ModelVector<int64_t>>(),
        .sendTrackOrder = std::make_shared<ModelVector<int64_t>>(),
        .filePath = std::nullopt,
        .isDirty = false,
    });
  }

  static const AutomationSpanListCollection* getCompiledSequence(EntityId sequenceId) {
    return Engine::getInstance().automationSequenceStore->getSequence(sequenceId);
  }

  static const AutomationSpanList* getTrack(
      const AutomationSpanListCollection* sequence, EntityId trackId) {
    if (sequence == nullptr) {
      return nullptr;
    }

    auto trackIter = sequence->tracks.find(trackId);
    if (trackIter == sequence->tracks.end()) {
      return nullptr;
    }

    return trackIter->second;
  }
public:
  AutomationSequenceCompilerTest() : juce::UnitTest("AutomationSequenceCompilerTest", "Anthem") {}

  void runTest() override {
    testCompilePatternWritesNoTrackAutomation();
    testClipTimeViewPreservesSourceCurvePosition();
    testOverlappingClipsUseLaterClipWinsRule();
    testIncrementalCompileReplacesAutomationTrack();

    Engine::cleanup();
  }

  void testCompilePatternWritesNoTrackAutomation() {
    beginTest("Pattern automation compilation writes no-track spans");

    auto pattern = makePattern(pattern1Id,
        {
            makePoint(point1Id, 0, 0.25),
            makePoint(point2Id, 100, 0.75),
        });

    installProject({pattern}, nullptr);

    AutomationSequenceCompiler::compilePattern(pattern1Id);

    auto* compiledPattern = getCompiledSequence(pattern1Id);
    auto* track = getTrack(compiledPattern, sequencer_track_ids::noTrack);

    expect(track != nullptr, "No-track automation should exist");
    expect(track->hasInitialValue, "Automation track should have an initial value");
    expect(nearlyEqual(track->initialValue, 0.25), "Initial value should use the first point");
    expect(track->spans.size() == 2, "Curve and final hold spans should be compiled");
    expect(nearlyEqual(track->spans.at(0).startTick, 0.0), "Curve starts at zero");
    expect(nearlyEqual(track->spans.at(0).endTick, 100.0), "Curve ends at second point");
    expect(std::isinf(track->spans.at(1).endTick), "Final hold should continue indefinitely");

    Engine::cleanup();
  }

  void testClipTimeViewPreservesSourceCurvePosition() {
    beginTest("Clipped automation curves preserve normalized source positions");

    auto pattern = makePattern(pattern1Id,
        {
            makePoint(point1Id, 0, 0.0),
            makePoint(point2Id, 100, 1.0),
        });
    auto arrangement = makeArrangement({
        makeClip(clip1Id, pattern1Id, track1Id, 200, std::make_tuple(50, 100)),
    });

    installProject({pattern}, arrangement);

    AutomationSequenceCompiler::compileArrangement();

    auto* track = getTrack(getCompiledSequence(arrangementId), track1Id);
    expect(track != nullptr, "Track automation should exist");
    expect(nearlyEqual(track->initialValue, 0.5), "Initial value should evaluate clip start");
    expect(track->spans.size() == 2, "Clipped curve and final hold should be compiled");

    const auto& curve = track->spans.at(0);
    expect(nearlyEqual(curve.startTick, 200.0), "Clipped curve starts at clip offset");
    expect(nearlyEqual(curve.endTick, 250.0), "Clipped curve duration matches time view");
    expect(nearlyEqual(curve.sourceCurveStartNormalized, 0.5),
        "Source curve start should point halfway through the original curve");
    expect(nearlyEqual(curve.sourceCurveEndNormalized, 1.0),
        "Source curve end should point to the original curve end");

    Engine::cleanup();
  }

  void testOverlappingClipsUseLaterClipWinsRule() {
    beginTest("Overlapping automation clips use later-clip-wins deconfliction");

    auto pattern1 = makePattern(pattern1Id,
        {
            makePoint(point1Id, 0, 0.1),
            makePoint(point2Id, 10, 0.2),
        });
    auto pattern2 = makePattern(pattern2Id,
        {
            makePoint(point3Id, 0, 0.8),
            makePoint(point4Id, 10, 0.9),
        });
    auto arrangement = makeArrangement({
        makeClip(clip1Id, pattern1Id, track1Id, 0),
        makeClip(clip2Id, pattern2Id, track1Id, 5),
    });

    installProject({pattern1, pattern2}, arrangement);

    AutomationSequenceCompiler::compileArrangement();

    auto* track = getTrack(getCompiledSequence(arrangementId), track1Id);
    expect(track != nullptr, "Track automation should exist");
    expect(track->spans.size() == 3,
        "Earlier clip should be truncated, then later curve and hold should remain");
    expect(nearlyEqual(track->spans.at(0).startTick, 0.0), "First clip starts at zero");
    expect(nearlyEqual(track->spans.at(0).endTick, 5.0),
        "First clip should stop when the later clip starts");
    expect(nearlyEqual(track->spans.at(1).startTick, 5.0), "Later clip starts at tick 5");
    expect(nearlyEqual(track->spans.at(1).startValue, 0.8),
        "Later clip value should take over at its start");
    expect(std::isinf(track->spans.at(2).endTick), "Later clip should hold indefinitely");

    Engine::cleanup();
  }

  void testIncrementalCompileReplacesAutomationTrack() {
    beginTest("Automation incremental compilation replaces automation track");

    auto pattern = makePattern(pattern1Id,
        {
            makePoint(point1Id, 0, 0.25),
            makePoint(point2Id, 100, 0.75),
        });

    installProject({pattern}, nullptr);

    AutomationSequenceCompiler::compilePattern(pattern1Id);

    std::vector<EntityId> trackIdsToRebuild{sequencer_track_ids::noTrack};
    AutomationSequenceCompiler::compilePattern(pattern1Id, trackIdsToRebuild);

    auto* track = getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack);
    expect(track != nullptr, "No-track automation should exist after incremental compile");
    expect(track->hasInitialValue, "Incremental compile should publish automation data");
    expect(track->spans.size() == 2, "Incremental compile should rebuild the no-track automation");

    Engine::cleanup();
  }
};

static AutomationSequenceCompilerTest automationSequenceCompilerTest;

} // namespace anthem
