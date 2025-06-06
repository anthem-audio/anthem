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

part of 'pattern.dart';

mixin _PatternCompilerMixin on _PatternModel {
  void _recompileModifiedNotes(
    Iterable<FieldAccessor> fieldAccessors,
    FieldOperation operation,
  ) {
    final channelIdFieldAccessor = fieldAccessors.first;
    final channelId = channelIdFieldAccessor.key;

    // Shouldn't happen, but safety first
    if (channelId == null) {
      return;
    }

    // This is for adding, removing, or replacing notes
    if (fieldAccessors.length == 2) {
      final (oldNote, newNote) = switch (operation) {
        RawFieldUpdate() => throw StateError(
          'A raw field operation is not valid here',
        ),
        ListInsert() => (null, operation.valueAs<NoteModel>()),
        ListRemove() => (operation.removedValueAs<NoteModel>(), null),
        ListUpdate() => (
          operation.oldValueAs<NoteModel>(),
          operation.newValueAs<NoteModel>(),
        ),
        MapPut() => throw StateError('A map operation is not valid here'),
        MapRemove() => throw StateError('A map operation is not valid here'),
      };

      if (oldNote != null) {
        _channelsToCompile.add(channelId);
        _patternInvalidationRangeCollector.addRange(
          oldNote.offset,
          oldNote.offset + oldNote.length,
        );

        _schedulePatternCompile(true);
      }

      if (newNote != null) {
        _channelsToCompile.add(channelId);
        _patternInvalidationRangeCollector.addRange(
          newNote.offset,
          newNote.offset + newNote.length,
        );

        _schedulePatternCompile(true);
      }
    }
    // This is for editing note attributes
    else if (fieldAccessors.length == 3) {
      final listAccessor = fieldAccessors.elementAt(1);
      final accessor = fieldAccessors.elementAt(2);

      if (accessor.fieldName == 'offset' ||
          accessor.fieldName == 'length' ||
          accessor.fieldName == 'key') {
        final channel = notes[channelId]!;
        final note = channel[listAccessor.index!];
        operation as RawFieldUpdate;

        if (accessor.fieldName == 'offset') {
          final oldValue = operation.oldValueAs<int>();
          final newValue = operation.newValueAs<int>();

          _channelsToCompile.add(channelId);
          _patternInvalidationRangeCollector.addRange(
            oldValue,
            oldValue + note.length,
          );
          _patternInvalidationRangeCollector.addRange(
            newValue,
            newValue + note.length,
          );

          _schedulePatternCompile(true);
        } else if (accessor.fieldName == 'length') {
          final oldValue = operation.oldValueAs<int>();
          final newValue = operation.newValueAs<int>();

          _channelsToCompile.add(channelId);
          _patternInvalidationRangeCollector.addRange(
            note.offset,
            note.offset + max(oldValue, newValue),
          );

          _schedulePatternCompile(true);
        } else if (accessor.fieldName == 'key') {
          // If the key is changed, we need to recompile the pattern
          _channelsToCompile.add(channelId);
          _patternInvalidationRangeCollector.addRange(
            note.offset,
            note.offset + note.length,
          );

          _schedulePatternCompile(true);
        }
      }
    }
  }

  final Set<Id> _channelsToCompile = {};
  final InvalidationRangeCollector _patternInvalidationRangeCollector =
      InvalidationRangeCollector();
  final InvalidationRangeCollector _arrangementInvalidationRangeCollector =
      InvalidationRangeCollector();
  bool _updateArrangements = false;
  bool _isScheduled = false;
  void _schedulePatternCompile(bool updateArrangements) {
    _updateArrangements = _updateArrangements || updateArrangements;

    if (_isScheduled) {
      return;
    }

    _isScheduled = true;

    // Schedule a microtask to compile the pattern
    Future.microtask(() {
      void reset() {
        _channelsToCompile.clear();
        _patternInvalidationRangeCollector.reset();
        _isScheduled = false;
        _updateArrangements = false;
      }

      if (_channelsToCompile.isEmpty) {
        reset();
        return;
      }

      final project = this.project;
      final engine = project.engine;
      if (!engine.isRunning) {
        reset();
        return;
      }

      // Compile the pattern
      engine.sequencerApi.compilePattern(
        id,
        channelsToRebuild: _channelsToCompile.toList(),
        invalidationRanges: _patternInvalidationRangeCollector.getRanges(),
      );

      // If we need to update the arrangement, do so
      if (_updateArrangements) {
        for (final arrangement in project.sequence.arrangements.values) {
          // For each clip, we need to apply the invalidation
          for (final clip in arrangement.clips.values) {
            if (clip.patternId != id) {
              continue;
            }

            var clipTimeViewStart = 0;
            var clipTimeViewEnd = 0x7FFF_FFFF_FFFF_FFFF;

            if (clip.timeView != null) {
              clipTimeViewStart = clip.timeView!.start;
              clipTimeViewEnd = clip.timeView!.end;
            }

            for (var i = 0; i < _patternInvalidationRangeCollector.size; i++) {
              final patternInvalidationRangeStart =
                  _patternInvalidationRangeCollector.rawData[i * 2];
              final patternInvalidationRangeEnd =
                  _patternInvalidationRangeCollector.rawData[i * 2 + 1];

              final adjustedPatternRangeStart =
                  max(
                    clipTimeViewStart,
                    patternInvalidationRangeStart + clip.offset,
                  ) -
                  clipTimeViewStart;

              final adjustedPatternRangeEnd =
                  min(
                    clipTimeViewEnd,
                    patternInvalidationRangeEnd + clip.offset,
                  ) -
                  clipTimeViewStart;

              if (adjustedPatternRangeStart >= adjustedPatternRangeEnd) {
                continue;
              }

              final arrangementRangeStart =
                  adjustedPatternRangeStart + clip.offset;
              final arrangementRangeEnd = adjustedPatternRangeEnd + clip.offset;

              _arrangementInvalidationRangeCollector.addRange(
                arrangementRangeStart,
                arrangementRangeEnd,
              );
            }
          }

          // We have invalidation ranges for the pattern - we need to apply them
          // for each clip in the arrangement.
          engine.sequencerApi.compileArrangement(
            arrangement.id,
            invalidationRanges: _arrangementInvalidationRangeCollector
                .getRanges(),
          );

          _arrangementInvalidationRangeCollector.reset();
        }
      }

      // Reset the state after compiling
      reset();
    });
  }
}
