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

#include "modules/core/engine.h"
#include "modules/sequencer/compiler/sequence_compiler.h"

#include <cmath>
#include <initializer_list>

namespace anthem {

class SequenceCompilerTest : public juce::UnitTest {
  static constexpr EntityId pattern1Id = 101;
  static constexpr EntityId pattern2Id = 102;
  static constexpr EntityId missingPatternId = 999;
  static constexpr EntityId arrangementId = 201;
  static constexpr EntityId track1Id = 301;
  static constexpr EntityId track2Id = 302;
  static constexpr EntityId track3Id = 303;
  static constexpr EntityId clip1Id = 401;
  static constexpr EntityId clip2Id = 402;
  static constexpr EntityId clip3Id = 403;
  static constexpr EntityId note1Id = 501;
  static constexpr EntityId note2Id = 502;
  static constexpr EntityId note3Id = 503;
  static constexpr EntityId note4Id = 504;

  static bool nearlyEqual(double a, double b) {
    return std::fabs(a - b) < 0.0001;
  }

  static std::shared_ptr<NoteModel> makeNote(
      EntityId noteId, int64_t key, int64_t offset, int64_t length, double velocity = 0.75) {
    return std::make_shared<NoteModel>(NoteModelImpl{
        .id = noteId,
        .key = key,
        .velocity = velocity,
        .length = length,
        .offset = offset,
        .pan = 0.0,
    });
  }

  static std::shared_ptr<PatternModel> makePattern(
      EntityId patternId, std::initializer_list<std::shared_ptr<NoteModel>> notes) {
    auto noteMap = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<NoteModel>>>();

    for (const auto& note : notes) {
      noteMap->insert_or_assign(note->id(), note);
    }

    return std::make_shared<PatternModel>(PatternModelImpl{
        .id = patternId,
        .name = "Pattern",
        .color = nullptr,
        .notes = noteMap,
        .automation = nullptr,
        .timeSignatureChanges =
            std::make_shared<ModelVector<std::shared_ptr<TimeSignatureChangeModel>>>(),
        .loopPoints = std::nullopt,
    });
  }

  static std::shared_ptr<ClipModel> makeClip(EntityId clipId,
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
        .id = clipId,
        .timeView = timeViewModel,
        .patternId = patternId,
        .trackId = trackId,
        .offset = offset,
    });
  }

  static std::shared_ptr<ArrangementModel> makeArrangement(
      EntityId id, std::initializer_list<std::shared_ptr<ClipModel>> clips) {
    auto clipMap = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<ClipModel>>>();

    for (const auto& clip : clips) {
      clipMap->insert_or_assign(clip->id(), clip);
    }

    return std::make_shared<ArrangementModel>(ArrangementModelImpl{
        .id = id,
        .name = "Arrangement",
        .clips = clipMap,
        .timeSignatureChanges =
            std::make_shared<ModelVector<std::shared_ptr<TimeSignatureChangeModel>>>(),
        .loopPoints = std::nullopt,
    });
  }

  static std::shared_ptr<Sequencer> makeSequencer(
      std::initializer_list<std::shared_ptr<PatternModel>> patterns,
      std::initializer_list<std::shared_ptr<ArrangementModel>> arrangements) {
    auto patternMap = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<PatternModel>>>();
    auto arrangementMap =
        std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<ArrangementModel>>>();

    for (const auto& pattern : patterns) {
      patternMap->insert_or_assign(pattern->id(), pattern);
    }

    for (const auto& arrangement : arrangements) {
      arrangementMap->insert_or_assign(arrangement->id(), arrangement);
    }

    return std::make_shared<Sequencer>(SequencerModelImpl{
        .ticksPerQuarter = 96,
        .beatsPerMinuteRaw = 12000,
        .patterns = patternMap,
        .activePatternID = std::nullopt,
        .activeTrackID = std::nullopt,
        .arrangements = arrangementMap,
        .arrangementOrder = std::make_shared<ModelVector<int64_t>>(),
        .activeArrangementID = std::nullopt,
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
      std::initializer_list<std::shared_ptr<ArrangementModel>> arrangements,
      std::initializer_list<EntityId> trackOrder) {
    Engine::cleanup();

    auto tracks = std::make_shared<ModelUnorderedMap<int64_t, std::shared_ptr<TrackModel>>>();
    auto trackOrderVector = std::make_shared<ModelVector<int64_t>>();

    for (auto trackId : trackOrder) {
      trackOrderVector->push_back(trackId);
    }

    auto& engine = Engine::getInstance();
    engine.sequenceStore = std::make_unique<RuntimeSequenceStore>();
    engine.project = std::make_shared<Project>(ProjectModelImpl{
        .sequence = makeSequencer(patterns, arrangements),
        .processingGraph = nullptr,
        .masterOutputNodeId = std::nullopt,
        .tracks = tracks,
        .trackOrder = trackOrderVector,
        .sendTrackOrder = std::make_shared<ModelVector<int64_t>>(),
        .filePath = std::nullopt,
        .isDirty = false,
    });
  }

  static const SequenceEventListCollection* getCompiledSequence(EntityId sequenceId) {
    return Engine::getInstance().sequenceStore->getSequenceEventList(sequenceId);
  }

  static const SequenceEventList* getTrack(
      const SequenceEventListCollection* sequence, EntityId trackId) {
    if (sequence == nullptr) {
      return nullptr;
    }

    auto track = sequence->tracks.find(trackId);
    if (track == sequence->tracks.end()) {
      return nullptr;
    }

    return track->second;
  }

  bool isSorted(const std::vector<SequenceEvent>& events) {
    for (size_t i = 1; i < events.size(); i++) {
      if (events.at(i - 1).offset > events.at(i).offset) {
        return false;
      }

      if (nearlyEqual(events.at(i - 1).offset, events.at(i).offset) &&
          events.at(i - 1).event.type > events.at(i).event.type) {
        return false;
      }
    }

    return true;
  }

  void expectNoteOn(const SequenceEvent& event,
      double offset,
      SourceNoteId sourceId,
      int16_t pitch,
      float velocity,
      const juce::String& context) {
    expect(nearlyEqual(event.offset, offset), context + " offset");
    expect(event.sourceId == sourceId, context + " source ID");
    expect(event.event.type == EventType::NoteOn, context + " event type");

    if (event.event.type == EventType::NoteOn) {
      expectEquals(event.event.noteOn.pitch, pitch, context + " pitch");
      expectEquals(event.event.noteOn.channel, static_cast<int16_t>(0), context + " channel");
      expect(nearlyEqual(event.event.noteOn.velocity, velocity), context + " velocity");
    }
  }

  void expectNoteOff(const SequenceEvent& event,
      double offset,
      SourceNoteId sourceId,
      int16_t pitch,
      const juce::String& context) {
    expect(nearlyEqual(event.offset, offset), context + " offset");
    expect(event.sourceId == sourceId, context + " source ID");
    expect(event.event.type == EventType::NoteOff, context + " event type");

    if (event.event.type == EventType::NoteOff) {
      expectEquals(event.event.noteOff.pitch, pitch, context + " pitch");
      expectEquals(event.event.noteOff.channel, static_cast<int16_t>(0), context + " channel");
    }
  }
public:
  SequenceCompilerTest() : juce::UnitTest("SequenceCompilerTest", "Anthem") {}

  void runTest() override {
    testEventSorting();
    testClampTimeToRange();
    testClampStartAndEndToRange();
    testCompilePatternWritesNoTrackEvents();
    testCompilePatternRebuildsNoTrackIncrementally();
    testCompileArrangementCompilesTracksAndClips();
    testCompileArrangementRebuildsRequestedTracksOnly();
    testCleanUpTrackRemovesTrackFromCompiledSequences();

    Engine::cleanup();
  }

  void testEventSorting() {
    beginTest("Event sorting");

    auto eventList = std::vector<SequenceEvent>();
    SequenceCompiler::sortEventList(eventList);

    eventList.push_back(SequenceEvent{.offset = 1.0, .event = Event(NoteOnEvent())});

    eventList.push_back(SequenceEvent{.offset = 1.0, .event = Event(NoteOffEvent())});

    eventList.push_back(SequenceEvent{.offset = 0.5, .event = Event(NoteOnEvent())});

    SequenceCompiler::sortEventList(eventList);

    expect(eventList.size() == 3, "There are three events");
    expect(isSorted(eventList), "The events are sorted");
    expect(nearlyEqual(eventList.at(0).offset, 0.5), "First event offset is 0.5");
    expect(eventList.at(1).event.type == EventType::NoteOff,
        "NoteOff is ordered before NoteOn at equal offset");
    expect(eventList.at(2).event.type == EventType::NoteOn,
        "NoteOn is ordered after NoteOff at equal offset");
  }

  void testClampTimeToRange() {
    beginTest("ClampTimeToRange");

    auto range = std::make_tuple(20.0, 30.0);

    expect(nearlyEqual(SequenceCompiler::clampTimeToRange(10.0, range), 20.0),
        "Time below range clamps to start");
    expect(nearlyEqual(SequenceCompiler::clampTimeToRange(40.0, range), 30.0),
        "Time above range clamps to end");
    expect(nearlyEqual(SequenceCompiler::clampTimeToRange(25.5, range), 25.5),
        "Time in range is unchanged");
    expect(nearlyEqual(SequenceCompiler::clampTimeToRange(20.0, range), 20.0),
        "Range start is unchanged");
    expect(nearlyEqual(SequenceCompiler::clampTimeToRange(30.0, range), 30.0),
        "Range end is unchanged");
  }

  void testClampStartAndEndToRange() {
    beginTest("ClampStartAndEndToRange");

    auto range = std::make_optional(std::make_tuple(20.0, 30.0));

    std::optional<std::tuple<double, double>> clampedRange;

    // Entirely before range -> no output
    clampedRange = SequenceCompiler::clampStartAndEndToRange(5.0, 10.0, range);
    expect(!clampedRange.has_value(), "Times before range should return nullopt");

    // Entirely after range -> no output
    clampedRange = SequenceCompiler::clampStartAndEndToRange(30.0, 35.0, range);
    expect(!clampedRange.has_value(), "Times after range should return nullopt");

    // Exact bounds -> unchanged
    clampedRange = SequenceCompiler::clampStartAndEndToRange(20.0, 30.0, range);
    expect(clampedRange.has_value(), "Range bounds should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 20.0), "Start matches range start");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 30.0), "End matches range end");

    // Overlap left edge
    clampedRange = SequenceCompiler::clampStartAndEndToRange(15.0, 25.0, range);
    expect(clampedRange.has_value(), "Overlap left should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 20.0), "Start clamps to range start");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 25.0), "End remains in range");

    // Overlap right edge
    clampedRange = SequenceCompiler::clampStartAndEndToRange(25.0, 35.0, range);
    expect(clampedRange.has_value(), "Overlap right should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 25.0), "Start remains in range");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 30.0), "End clamps to range end");

    // No range -> unchanged
    clampedRange = SequenceCompiler::clampStartAndEndToRange(25.0, 35.0, std::nullopt);
    expect(clampedRange.has_value(), "No range should return value");
    expect(nearlyEqual(std::get<0>(clampedRange.value()), 25.0), "Start unchanged without range");
    expect(nearlyEqual(std::get<1>(clampedRange.value()), 35.0), "End unchanged without range");
  }

  void testCompilePatternWritesNoTrackEvents() {
    beginTest("Pattern compilation writes sorted no-track events");

    auto pattern = makePattern(pattern1Id,
        {
            makeNote(note1Id, 60, 24, 12, 0.8),
            makeNote(note2Id, 64, 0, 24, 0.6),
        });

    installProject({pattern}, {}, {});

    SequenceCompiler::compilePattern(missingPatternId);
    expect(getCompiledSequence(missingPatternId) == nullptr,
        "Missing patterns should not publish a compiled sequence");

    SequenceCompiler::compilePattern(pattern1Id);

    auto* compiledPattern = getCompiledSequence(pattern1Id);
    expect(compiledPattern != nullptr, "The pattern should be compiled");
    expect(compiledPattern->tracks.size() == 1, "A bare pattern should have one track");

    auto* noTrackEvents = getTrack(compiledPattern, sequencer_track_ids::noTrack);
    expect(noTrackEvents != nullptr, "Bare pattern events should be routed to no-track");
    expect(noTrackEvents->events.size() == 4, "Two notes should compile to four events");
    expect(isSorted(noTrackEvents->events), "Pattern events should be sorted");

    expectNoteOn(noTrackEvents->events.at(0),
        0.0,
        note_instance_ids::fromPatternNoteId(note2Id),
        64,
        0.6f,
        "First pattern note-on");
    expectNoteOff(noTrackEvents->events.at(1),
        24.0,
        note_instance_ids::fromPatternNoteId(note2Id),
        64,
        "First pattern note-off");
    expectNoteOn(noTrackEvents->events.at(2),
        24.0,
        note_instance_ids::fromPatternNoteId(note1Id),
        60,
        0.8f,
        "Second pattern note-on");
    expectNoteOff(noTrackEvents->events.at(3),
        36.0,
        note_instance_ids::fromPatternNoteId(note1Id),
        60,
        "Second pattern note-off");

    Engine::cleanup();
  }

  void testCompilePatternRebuildsNoTrackIncrementally() {
    beginTest("Pattern incremental compilation rebuilds no-track only");

    auto pattern = makePattern(pattern1Id, {makeNote(note1Id, 60, 0, 12)});
    installProject({pattern}, {}, {});

    SequenceCompiler::compilePattern(pattern1Id);
    auto* initialNoTrack = getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack);
    expect(initialNoTrack != nullptr, "Initial pattern no-track should exist");
    expect(initialNoTrack->events.size() == 2, "Initial pattern should have one note");

    pattern->notes()->insert_or_assign(note2Id, makeNote(note2Id, 67, 24, 6));

    std::vector<EntityId> trackIdsToRebuild{track1Id};
    std::vector<std::tuple<double, double>> invalidationRanges{{20.0, 40.0}};
    SequenceCompiler::compilePattern(pattern1Id, trackIdsToRebuild, invalidationRanges);

    auto* unchangedNoTrack =
        getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack);
    expect(unchangedNoTrack != nullptr, "No-track should still exist after skipped rebuild");
    expect(unchangedNoTrack->events.size() == 2,
        "A pattern rebuild without no-track should leave events unchanged");

    trackIdsToRebuild = {sequencer_track_ids::noTrack};
    SequenceCompiler::compilePattern(pattern1Id, trackIdsToRebuild, invalidationRanges);

    auto* rebuiltNoTrack = getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack);
    expect(rebuiltNoTrack != nullptr, "No-track should exist after rebuild");
    expect(rebuiltNoTrack->events.size() == 4, "No-track rebuild should pick up new notes");
    expect(rebuiltNoTrack->invalidationRanges.size() == 1,
        "No-track rebuild should preserve invalidation ranges");
    expect(nearlyEqual(std::get<0>(rebuiltNoTrack->invalidationRanges.at(0)), 20.0),
        "Invalidation start should be preserved");
    expect(nearlyEqual(std::get<1>(rebuiltNoTrack->invalidationRanges.at(0)), 40.0),
        "Invalidation end should be preserved");

    Engine::cleanup();
  }

  void testCompileArrangementCompilesTracksAndClips() {
    beginTest("Arrangement compilation handles tracks, clip ranges, offsets, and note IDs");

    auto pattern1 = makePattern(pattern1Id,
        {
            makeNote(note1Id, 60, 15, 10, 0.5),
            makeNote(note2Id, 62, 28, 8, 0.7),
            makeNote(note3Id, 65, 40, 6, 0.9),
        });
    auto pattern2 = makePattern(pattern2Id, {makeNote(note4Id, 72, 5, 7, 0.65)});

    auto arrangement = makeArrangement(arrangementId,
        {
            makeClip(clip1Id, pattern1Id, track1Id, 100, std::make_tuple(20, 32)),
            makeClip(clip2Id, pattern2Id, track2Id, 50),
            makeClip(clip3Id, missingPatternId, track1Id, 200),
        });

    installProject({pattern1, pattern2}, {arrangement}, {track1Id, track2Id, track3Id});

    SequenceCompiler::compileArrangement(arrangementId);

    auto* compiledArrangement = getCompiledSequence(arrangementId);
    expect(compiledArrangement != nullptr, "The arrangement should be compiled");
    expect(compiledArrangement->tracks.size() == 3,
        "Every track in trackOrder should get a compiled track");

    auto* track1Events = getTrack(compiledArrangement, track1Id);
    expect(track1Events != nullptr, "Track 1 events should exist");
    expect(track1Events->events.size() == 4,
        "Track 1 should include only clip-overlapping pattern notes");
    expect(isSorted(track1Events->events), "Track 1 events should be sorted");

    expectNoteOn(track1Events->events.at(0),
        100.0,
        note_instance_ids::fromArrangementClipNoteId(clip1Id, note1Id),
        60,
        0.5f,
        "Clamped left-edge note-on");
    expectNoteOff(track1Events->events.at(1),
        105.0,
        note_instance_ids::fromArrangementClipNoteId(clip1Id, note1Id),
        60,
        "Clamped left-edge note-off");
    expectNoteOn(track1Events->events.at(2),
        108.0,
        note_instance_ids::fromArrangementClipNoteId(clip1Id, note2Id),
        62,
        0.7f,
        "Clamped right-edge note-on");
    expectNoteOff(track1Events->events.at(3),
        112.0,
        note_instance_ids::fromArrangementClipNoteId(clip1Id, note2Id),
        62,
        "Clamped right-edge note-off");

    auto* track2Events = getTrack(compiledArrangement, track2Id);
    expect(track2Events != nullptr, "Track 2 events should exist");
    expect(track2Events->events.size() == 2, "Track 2 should include its clip note");

    expectNoteOn(track2Events->events.at(0),
        55.0,
        note_instance_ids::fromArrangementClipNoteId(clip2Id, note4Id),
        72,
        0.65f,
        "Offset-only clip note-on");
    expectNoteOff(track2Events->events.at(1),
        62.0,
        note_instance_ids::fromArrangementClipNoteId(clip2Id, note4Id),
        72,
        "Offset-only clip note-off");

    auto* track3Events = getTrack(compiledArrangement, track3Id);
    expect(track3Events != nullptr, "Track 3 events should exist");
    expect(track3Events->events.empty(), "Tracks without clips should compile to empty lists");

    Engine::cleanup();
  }

  void testCompileArrangementRebuildsRequestedTracksOnly() {
    beginTest("Arrangement incremental compilation rebuilds requested tracks only");

    auto pattern1 = makePattern(pattern1Id, {makeNote(note1Id, 60, 0, 10)});
    auto pattern2 = makePattern(pattern2Id, {makeNote(note2Id, 64, 0, 10)});
    auto arrangement = makeArrangement(arrangementId,
        {
            makeClip(clip1Id, pattern1Id, track1Id, 0),
            makeClip(clip2Id, pattern2Id, track2Id, 0),
        });

    installProject({pattern1, pattern2}, {arrangement}, {track1Id, track2Id});

    SequenceCompiler::compileArrangement(arrangementId);

    auto* initialTrack1 = getTrack(getCompiledSequence(arrangementId), track1Id);
    auto* initialTrack2 = getTrack(getCompiledSequence(arrangementId), track2Id);
    expect(initialTrack1 != nullptr, "Initial track 1 should exist");
    expect(initialTrack2 != nullptr, "Initial track 2 should exist");
    expect(initialTrack1->events.size() == 2, "Initial track 1 should have one note");
    expect(initialTrack2->events.size() == 2, "Initial track 2 should have one note");

    pattern1->notes()->insert_or_assign(note3Id, makeNote(note3Id, 67, 20, 5));
    pattern2->notes()->insert_or_assign(note4Id, makeNote(note4Id, 71, 20, 5));

    std::vector<EntityId> trackIdsToRebuild{track1Id};
    std::vector<std::tuple<double, double>> invalidationRanges{{18.0, 28.0}};
    SequenceCompiler::compileArrangement(arrangementId, trackIdsToRebuild, invalidationRanges);

    auto* rebuiltTrack1 = getTrack(getCompiledSequence(arrangementId), track1Id);
    auto* preservedTrack2 = getTrack(getCompiledSequence(arrangementId), track2Id);

    expect(rebuiltTrack1 != nullptr, "Rebuilt track 1 should exist");
    expect(preservedTrack2 != nullptr, "Preserved track 2 should exist");
    expect(rebuiltTrack1->events.size() == 4, "Requested track should pick up new notes");
    expect(preservedTrack2->events.size() == 2,
        "Unrequested track should keep its previous compiled events");
    expect(rebuiltTrack1->invalidationRanges.size() == 1,
        "Requested track should preserve invalidation ranges");
    expect(preservedTrack2->invalidationRanges.empty(),
        "Unrequested track should not receive invalidation ranges");

    Engine::cleanup();
  }

  void testCleanUpTrackRemovesTrackFromCompiledSequences() {
    beginTest("Track cleanup removes tracks from compiled sequences");

    auto pattern1 = makePattern(pattern1Id, {makeNote(note1Id, 60, 0, 10)});
    auto pattern2 = makePattern(pattern2Id, {makeNote(note2Id, 64, 0, 10)});
    auto arrangement = makeArrangement(arrangementId,
        {
            makeClip(clip1Id, pattern1Id, track1Id, 0),
            makeClip(clip2Id, pattern2Id, track2Id, 0),
        });

    installProject({pattern1, pattern2}, {arrangement}, {track1Id, track2Id});

    SequenceCompiler::compilePattern(pattern1Id);
    SequenceCompiler::compileArrangement(arrangementId);

    expect(getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack) != nullptr,
        "Pattern no-track should exist before cleanup");
    expect(getTrack(getCompiledSequence(arrangementId), track1Id) != nullptr,
        "Track 1 should exist before cleanup");
    expect(getTrack(getCompiledSequence(arrangementId), track2Id) != nullptr,
        "Track 2 should exist before cleanup");

    SequenceCompiler::cleanUpTrack(track1Id);

    expect(getTrack(getCompiledSequence(pattern1Id), sequencer_track_ids::noTrack) != nullptr,
        "Pattern no-track should be preserved by track cleanup");
    expect(getTrack(getCompiledSequence(arrangementId), track1Id) == nullptr,
        "Track 1 should be removed from the arrangement");
    expect(getTrack(getCompiledSequence(arrangementId), track2Id) != nullptr,
        "Other tracks should be preserved");

    Engine::cleanup();
  }
};

static SequenceCompilerTest sequenceCompilerTest;

} // namespace anthem
