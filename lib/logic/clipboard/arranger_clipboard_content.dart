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

part of 'clipboard_data.dart';

typedef ReconstructedArrangerClipboardContent = ({
  List<PatternModel> patterns,
  List<ClipModel> clips,
});

final class ArrangerClipboardContent extends ClipboardContent {
  final int anchorOffset;
  final List<Map<String, dynamic>> serializedClips;
  final Map<Id, Map<String, dynamic>> serializedPatternsBySourceId;

  ArrangerClipboardContent({
    required this.anchorOffset,
    required Iterable<ClipModel> clips,
    required Iterable<PatternModel> patterns,
  }) : serializedClips = clips.map((clip) => clip.toJson()).toList(),
       serializedPatternsBySourceId = {
         for (final pattern in patterns) pattern.id: pattern.toJson(),
       };

  ReconstructedArrangerClipboardContent reconstruct({
    required ProjectEntityIdAllocator idAllocator,
    required int newAnchorOffset,
    required Set<Id> availableTrackIds,
  }) {
    final patternIdBySourceId = <Id, Id>{};
    final reconstructedPatternsBySourceId = <Id, PatternModel>{};

    for (final entry in serializedPatternsBySourceId.entries) {
      final pattern = PatternModel.fromJson(entry.value);
      pattern.id = idAllocator.allocateId();
      _remapPatternIds(pattern, idAllocator);

      patternIdBySourceId[entry.key] = pattern.id;
      reconstructedPatternsBySourceId[entry.key] = pattern;
    }

    final usedPatternIds = <Id>{};
    final clips = <ClipModel>[];

    for (final clipJson in serializedClips) {
      final clip = ClipModel.fromJson(clipJson);
      if (!availableTrackIds.contains(clip.trackId)) {
        continue;
      }

      final sourcePatternId = clip.patternId;
      final newPatternId = patternIdBySourceId[sourcePatternId];
      if (newPatternId == null) {
        continue;
      }

      clip.id = idAllocator.allocateSequenceClipId();
      clip.patternId = newPatternId;
      clip.offset = clip.offset - anchorOffset + newAnchorOffset;

      usedPatternIds.add(newPatternId);
      clips.add(clip);
    }

    final patterns = reconstructedPatternsBySourceId.values
        .where((pattern) => usedPatternIds.contains(pattern.id))
        .toList(growable: false);

    return (patterns: patterns, clips: clips);
  }

  void _remapPatternIds(
    PatternModel pattern,
    ProjectEntityIdAllocator idAllocator,
  ) {
    final notes = pattern.notes.values.toList(growable: false);
    final remappedNotes = AnthemObservableMap<Id, NoteModel>();
    for (final note in notes) {
      note.id = idAllocator.allocateSequenceNoteId();
      remappedNotes[note.id] = note;
    }
    pattern.notes = remappedNotes;

    pattern.noteOverrides = AnthemObservableMap<Id, PatternNoteOverrideModel>();
    pattern.previewNotes = AnthemObservableMap<Id, NoteModel>();
    pattern.loopPoints = null;

    for (final point in pattern.automation.points) {
      point.id = idAllocator.allocateId();
    }

    for (final change in pattern.timeSignatureChanges) {
      change.id = idAllocator.allocateId();
    }
  }
}
