/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/note.dart';

import 'state_machine/arranger_state_machine_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ArrangerStateMachineTestFixture fixture;

  setUp(() {
    ServiceRegistry.clipboard.clear();
    fixture = ArrangerStateMachineTestFixture.create();
  });

  tearDown(() {
    ServiceRegistry.clipboard.clear();
    fixture.dispose();
  });

  ({PatternModel pattern, NoteModel note}) addPatternWithNote({
    required int key,
  }) {
    final pattern = PatternModel(
      idAllocator: fixture.project.idAllocator,
      name: 'Pattern $key',
    );
    final note = NoteModel(
      idAllocator: fixture.project.idAllocator,
      key: key,
      velocity: 0.75,
      length: 96,
      offset: 0,
      pan: 0,
    );

    pattern.notes[note.id] = note;
    fixture.project.sequence.patterns[pattern.id] = pattern;

    return (pattern: pattern, note: note);
  }

  ClipModel addClipForPattern({
    required PatternModel pattern,
    required Id trackId,
    required int offset,
  }) {
    final clip = ClipModel(
      idAllocator: fixture.project.idAllocator,
      patternId: pattern.id,
      trackId: trackId,
      offset: offset,
      timeView: TimeViewModel(start: 0, end: 96),
    );

    fixture.arrangement.clips[clip.id] = clip;

    return clip;
  }

  group('controller clipboard commands', () {
    test('shortcut copy stores selected clips and deduped patterns', () {
      final (:pattern, note: _) = addPatternWithNote(key: 60);
      final clipA = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.a,
        offset: 96,
      );
      final clipB = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.b,
        offset: 192,
      );
      fixture.viewModel.selectedClips.addAll({clipA.id, clipB.id});

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );

      final content = ServiceRegistry.clipboard.get<ArrangerClipboardContent>();

      expect(content, isNotNull);
      expect(content!.anchorOffset, equals(96));
      expect(content.serializedClips, hasLength(2));
      expect(
        content.serializedClips.map((clipJson) => clipJson['id']).toSet(),
        equals({clipA.id, clipB.id}),
      );
      expect(content.serializedPatternsBySourceId.keys, equals({pattern.id}));
      expect(
        content.serializedPatternsBySourceId[pattern.id]!['id'],
        pattern.id,
      );
      expect(fixture.arrangement.clips.keys, containsAll({clipA.id, clipB.id}));
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({clipA.id, clipB.id}),
      );
    });

    test('shortcut paste uses the visible playback start', () {
      final (:pattern, :note) = addPatternWithNote(key: 64);
      final clipA = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.a,
        offset: 96,
      );
      final clipB = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.b,
        offset: 192,
      );
      fixture.viewModel.selectedClips.addAll({clipA.id, clipB.id});
      fixture.project.sequence.activeTransportSequenceID =
          fixture.project.sequence.activeArrangementID;
      fixture.project.sequence.playbackStartPosition = 384;
      final patternIdsBeforePaste = fixture.project.sequence.patterns.keys
          .toSet();

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );
      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      );

      final pastedClips =
          fixture.viewModel.selectedClips
              .map((clipId) => fixture.arrangement.clips[clipId]!)
              .toList(growable: false)
            ..sort((a, b) => a.offset.compareTo(b.offset));
      final pastedClipIds = pastedClips.map((clip) => clip.id).toSet();
      final clonedPatternIds = fixture.project.sequence.patterns.keys
          .toSet()
          .difference(patternIdsBeforePaste);

      expect(pastedClips, hasLength(2));
      expect(pastedClipIds, isNot(contains(clipA.id)));
      expect(pastedClipIds, isNot(contains(clipB.id)));
      expect(pastedClips[0].offset, equals(384));
      expect(pastedClips[1].offset, equals(480));
      expect(pastedClips[0].trackId, equals(TrackIds.a));
      expect(pastedClips[1].trackId, equals(TrackIds.b));
      expect(pastedClips.map((clip) => clip.patternId).toSet(), hasLength(1));
      expect(clonedPatternIds, hasLength(1));

      final clonedPattern =
          fixture.project.sequence.patterns[clonedPatternIds.single]!;
      expect(pastedClips.first.patternId, clonedPattern.id);
      expect(clonedPattern.id, isNot(pattern.id));
      expect(clonedPattern.notes.keys.single, isNot(note.id));
      expect(clonedPattern.notes.values.single.key, equals(note.key));

      fixture.project.undo();
      expect(fixture.arrangement.clips.keys, isNot(containsAll(pastedClipIds)));
      expect(
        fixture.project.sequence.patterns.keys,
        isNot(contains(clonedPattern.id)),
      );

      fixture.project.redo();
      expect(fixture.arrangement.clips.keys, containsAll(pastedClipIds));
      expect(
        fixture.project.sequence.patterns.keys,
        contains(clonedPattern.id),
      );
    });

    test('shortcut paste falls back when playback start is off screen', () {
      final (:pattern, note: _) = addPatternWithNote(key: 67);
      final clip = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.a,
        offset: 96,
      );
      fixture.viewModel.selectedClips.add(clip.id);
      fixture.viewModel.timeRange = TimeRange(0, 960);
      fixture.project.sequence.activeTransportSequenceID =
          fixture.project.sequence.activeArrangementID;
      fixture.project.sequence.playbackStartPosition = 1000;

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );
      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      );

      final pastedClipId = fixture.viewModel.selectedClips.single;
      final pastedClip = fixture.arrangement.clips[pastedClipId]!;

      expect(pastedClip.id, isNot(clip.id));
      expect(pastedClip.offset, equals(0));
      expect(pastedClip.trackId, equals(clip.trackId));
    });

    test('shortcut cut copies selected clips and deletes them', () {
      final (:pattern, note: _) = addPatternWithNote(key: 72);
      final clip = addClipForPattern(
        pattern: pattern,
        trackId: TrackIds.a,
        offset: 96,
      );
      fixture.viewModel.selectedClips.add(clip.id);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX),
      );

      final content = ServiceRegistry.clipboard.get<ArrangerClipboardContent>();

      expect(content, isNotNull);
      expect(content!.serializedClips.single['id'], equals(clip.id));
      expect(fixture.arrangement.clips.keys, isNot(contains(clip.id)));
      expect(
        fixture.project.sequence.patterns.keys,
        isNot(contains(pattern.id)),
      );
      expect(fixture.viewModel.selectedClips, isEmpty);

      fixture.project.undo();
      expect(fixture.arrangement.clips.keys, contains(clip.id));
      expect(fixture.project.sequence.patterns.keys, contains(pattern.id));
    });
  });
}

extension on ArrangerStateMachineTestFixture {
  ArrangementModel get arrangement {
    return project.sequence.arrangements[project.sequence.activeArrangementID]!;
  }
}
