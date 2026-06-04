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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconstruct clones deduped patterns and remaps child IDs', () {
    var nextSourceId = 1;
    final sourceIdAllocator = ProjectEntityIdAllocator.test(
      () => nextSourceId++,
    );
    final sourcePattern = PatternModel(
      idAllocator: sourceIdAllocator,
      name: 'Source pattern',
    );
    final sourceNote = NoteModel(
      idAllocator: sourceIdAllocator,
      key: 60,
      velocity: 0.75,
      length: 96,
      offset: 24,
      pan: -0.1,
    );
    final sourceAutomationPoint = AutomationPointModel(
      idAllocator: sourceIdAllocator,
      offset: 48,
      value: 0.42,
    );
    final sourceTimeSignatureChange = TimeSignatureChangeModel(
      idAllocator: sourceIdAllocator,
      timeSignature: TimeSignatureModel(3, 4),
      offset: 96,
    );
    sourcePattern.notes[sourceNote.id] = sourceNote;
    sourcePattern.automation.points.add(sourceAutomationPoint);
    sourcePattern.timeSignatureChanges.add(sourceTimeSignatureChange);

    final sourceClipA = ClipModel(
      idAllocator: sourceIdAllocator,
      patternId: sourcePattern.id,
      trackId: 10,
      offset: 48,
      timeView: TimeViewModel(start: 0, end: 96),
    );
    final sourceClipB = ClipModel(
      idAllocator: sourceIdAllocator,
      patternId: sourcePattern.id,
      trackId: 11,
      offset: 96,
      timeView: TimeViewModel(start: 12, end: 108),
    );
    final content = ArrangerClipboardContent(
      anchorOffset: 48,
      clips: [sourceClipA, sourceClipB],
      patterns: [sourcePattern, sourcePattern],
    );
    var nextNewId = 100;
    final idAllocator = ProjectEntityIdAllocator.test(() => nextNewId++);

    final reconstructed = content.reconstruct(
      idAllocator: idAllocator,
      newAnchorOffset: 192,
      availableTrackIds: {10, 11},
    );

    expect(content.serializedPatternsBySourceId, hasLength(1));
    expect(reconstructed.patterns, hasLength(1));
    expect(reconstructed.clips, hasLength(2));

    final clonedPattern = reconstructed.patterns.single;
    expect(clonedPattern.id, isNot(sourcePattern.id));
    expect(clonedPattern.name, equals(sourcePattern.name));

    final clonedNote = clonedPattern.notes.values.single;
    expect(clonedNote.id, isNot(sourceNote.id));
    expect(clonedPattern.notes.keys.single, equals(clonedNote.id));
    expect(clonedNote.key, equals(sourceNote.key));
    expect(clonedNote.offset, equals(sourceNote.offset));

    final clonedAutomationPoint = clonedPattern.automation.points.single;
    expect(clonedAutomationPoint.id, isNot(sourceAutomationPoint.id));
    expect(clonedAutomationPoint.offset, equals(sourceAutomationPoint.offset));
    expect(clonedAutomationPoint.value, equals(sourceAutomationPoint.value));

    final clonedTimeSignatureChange = clonedPattern.timeSignatureChanges.single;
    expect(clonedTimeSignatureChange.id, isNot(sourceTimeSignatureChange.id));
    expect(clonedTimeSignatureChange.offset, sourceTimeSignatureChange.offset);
    expect(clonedTimeSignatureChange.timeSignature.numerator, 3);
    expect(clonedTimeSignatureChange.timeSignature.denominator, 4);

    expect(clonedPattern.noteOverrides, isEmpty);
    expect(clonedPattern.previewNotes, isEmpty);
    expect(clonedPattern.loopPoints, isNull);

    final clonedClips = reconstructed.clips.toList(growable: false)
      ..sort((a, b) => a.offset.compareTo(b.offset));
    expect(clonedClips[0].id, isNot(sourceClipA.id));
    expect(clonedClips[0].patternId, clonedPattern.id);
    expect(clonedClips[0].trackId, sourceClipA.trackId);
    expect(clonedClips[0].offset, 192);
    expect(clonedClips[0].timeView!.start, sourceClipA.timeView!.start);
    expect(clonedClips[0].timeView!.end, sourceClipA.timeView!.end);

    expect(clonedClips[1].id, isNot(sourceClipB.id));
    expect(clonedClips[1].patternId, clonedPattern.id);
    expect(clonedClips[1].trackId, sourceClipB.trackId);
    expect(clonedClips[1].offset, 240);
    expect(clonedClips[1].timeView!.start, sourceClipB.timeView!.start);
    expect(clonedClips[1].timeView!.end, sourceClipB.timeView!.end);

    expect(sourcePattern.notes.keys.single, sourceNote.id);
    expect(sourceClipA.patternId, sourcePattern.id);
  });

  test('reconstruct skips clips on tracks that do not exist', () {
    var nextSourceId = 1;
    final sourceIdAllocator = ProjectEntityIdAllocator.test(
      () => nextSourceId++,
    );
    final sourcePattern = PatternModel(
      idAllocator: sourceIdAllocator,
      name: 'Source pattern',
    );
    final sourceClip = ClipModel(
      idAllocator: sourceIdAllocator,
      patternId: sourcePattern.id,
      trackId: 10,
      offset: 48,
      timeView: TimeViewModel(start: 0, end: 96),
    );
    final content = ArrangerClipboardContent(
      anchorOffset: 48,
      clips: [sourceClip],
      patterns: [sourcePattern],
    );
    var nextNewId = 100;
    final idAllocator = ProjectEntityIdAllocator.test(() => nextNewId++);

    final reconstructed = content.reconstruct(
      idAllocator: idAllocator,
      newAnchorOffset: 192,
      availableTrackIds: {11},
    );

    expect(reconstructed.clips, isEmpty);
    expect(reconstructed.patterns, isEmpty);
  });
}
