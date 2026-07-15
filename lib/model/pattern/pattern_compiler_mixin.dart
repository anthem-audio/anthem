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

part of 'pattern.dart';

mixin _PatternCompilerMixin on _PatternModel {
  static const Id _noTrackEventListKey = -1;
  // 0x001F_FFFF_FFFF_FFFF is the max safe integer in JavaScript.
  static const int _unboundedClipEnd = 0x001F_FFFF_FFFF_FFFF;
  static const Duration _automationCompileDebounce = Duration(milliseconds: 75);

  final InvalidationRangeCollector _patternInvalidationRangeCollector =
      InvalidationRangeCollector();
  final InvalidationRangeCollector _arrangementInvalidationRangeCollector =
      InvalidationRangeCollector();
  bool _updateArrangements = false;
  bool _isImmediateCompileScheduled = false;
  bool _automationChanged = false;

  late final TimerDebouncedAction _automationCompileAction =
      TimerDebouncedAction(
        _flushScheduledPatternCompile,
        _automationCompileDebounce,
      );

  void _addPatternInvalidationRange(int start, int end) {
    if (end <= start) {
      return;
    }

    _patternInvalidationRangeCollector.addRange(start, end);
  }

  void _recompileOnNotesAddedOrRemoved(NoteModel? oldNote, NoteModel? newNote) {
    if (oldNote != null) {
      _addPatternInvalidationRange(
        oldNote.offset,
        oldNote.offset + oldNote.length,
      );
    }

    if (newNote != null) {
      _addPatternInvalidationRange(
        newNote.offset,
        newNote.offset + newNote.length,
      );
    }

    _schedulePatternCompile(updateArrangements: true);
  }

  FieldAccessor? _getLastFieldAccessor(Iterable<FieldAccessor> fieldAccessors) {
    FieldAccessor? result;
    for (final accessor in fieldAccessors) {
      result = accessor;
    }
    return result;
  }

  Id? _getMapKey(Iterable<FieldAccessor> fieldAccessors) {
    for (final accessor in fieldAccessors) {
      if (accessor.key is Id) {
        return accessor.key as Id;
      }
    }

    return null;
  }

  void _recompileOnNoteFieldChanged(ModelChangeEvent change) {
    final fieldAccessors = change.fieldAccessors;
    final operation = change.operation;

    if (operation is! RawFieldUpdate) {
      return;
    }

    final noteFieldAccessor = _getLastFieldAccessor(fieldAccessors);
    final noteFieldName = noteFieldAccessor?.fieldName;

    if (noteFieldName != 'offset' &&
        noteFieldName != 'length' &&
        noteFieldName != 'key' &&
        noteFieldName != 'velocity') {
      return;
    }

    final noteId = _getMapKey(fieldAccessors);
    if (noteId == null) {
      return;
    }

    final note = notes[noteId];
    if (note == null) {
      return;
    }

    if (noteFieldName == 'offset') {
      final oldValue = operation.oldValueAs<int>();
      final newValue = operation.newValueAs<int>();

      _addPatternInvalidationRange(oldValue, oldValue + note.length);
      _addPatternInvalidationRange(newValue, newValue + note.length);
    } else if (noteFieldName == 'length') {
      final oldValue = operation.oldValueAs<int>();
      final newValue = operation.newValueAs<int>();

      _addPatternInvalidationRange(
        note.offset + min(oldValue, newValue),
        note.offset + max(oldValue, newValue),
      );
    } else {
      _addPatternInvalidationRange(note.offset, note.offset + note.length);
    }

    _schedulePatternCompile(updateArrangements: true);
  }

  void _recompileOnAutomationPointsAddedOrRemoved(
    AutomationPointModel? oldPoint,
    AutomationPointModel? newPoint,
  ) {
    if (oldPoint == null && newPoint == null) {
      return;
    }

    _automationChanged = true;
    _schedulePatternCompile(updateArrangements: true, debounce: true);
  }

  void _recompileOnAutomationPointFieldChanged(ModelChangeEvent change) {
    final operation = change.operation;

    if (operation is! RawFieldUpdate) {
      return;
    }

    final fieldName = _getLastFieldAccessor(change.fieldAccessors)?.fieldName;
    if (fieldName != 'offset' &&
        fieldName != 'value' &&
        fieldName != 'tension' &&
        fieldName != 'curve') {
      return;
    }

    _automationChanged = true;
    _schedulePatternCompile(updateArrangements: true, debounce: true);
  }

  void _compileAffectedArrangements() {
    final engine = project.engine;
    final patternInvalidationSize = _patternInvalidationRangeCollector.size;
    final patternInvalidationData = _patternInvalidationRangeCollector.rawData;
    final arrangement = project.sequence.arrangement;

    if (arrangement.getPatternClipReferenceCount(id) == 0) {
      return;
    }

    _arrangementInvalidationRangeCollector.reset();
    final tracksToCompile = <Id>{};

    for (final clip in arrangement.clips.values) {
      if (clip.patternId != id) {
        continue;
      }

      final clipTimeViewStart = clip.timeView?.start ?? 0;
      final clipTimeViewEnd = clip.timeView?.end ?? _unboundedClipEnd;

      if (_automationChanged) {
        tracksToCompile.add(clip.trackId);
      }

      for (var i = 0; i < patternInvalidationSize; i++) {
        final patternInvalidationRangeStart = patternInvalidationData[i * 2];
        final patternInvalidationRangeEnd = patternInvalidationData[i * 2 + 1];

        final adjustedPatternRangeStart =
            max(clipTimeViewStart, patternInvalidationRangeStart) -
            clipTimeViewStart;
        final adjustedPatternRangeEnd =
            min(clipTimeViewEnd, patternInvalidationRangeEnd) -
            clipTimeViewStart;

        if (adjustedPatternRangeStart >= adjustedPatternRangeEnd) {
          continue;
        }

        tracksToCompile.add(clip.trackId);

        final arrangementRangeStart = adjustedPatternRangeStart + clip.offset;
        final arrangementRangeEnd = adjustedPatternRangeEnd + clip.offset;

        _arrangementInvalidationRangeCollector.addRange(
          arrangementRangeStart,
          arrangementRangeEnd,
        );
      }
    }

    if (tracksToCompile.isEmpty) {
      return;
    }

    engine.sequencerApi.compileArrangement(
      tracksToRebuild: tracksToCompile.toList(),
      invalidationRanges: _arrangementInvalidationRangeCollector.size > 0
          ? _arrangementInvalidationRangeCollector.getRanges()
          : null,
    );

    _arrangementInvalidationRangeCollector.reset();
  }

  void _flushScheduledPatternCompile() {
    void reset() {
      _patternInvalidationRangeCollector.reset();
      _updateArrangements = false;
      _automationChanged = false;
    }

    if (_patternInvalidationRangeCollector.size == 0 && !_automationChanged) {
      reset();
      return;
    }

    final engine = project.engine;
    if (!engine.isRunning) {
      reset();
      return;
    }

    engine.sequencerApi.compilePattern(
      id,
      tracksToRebuild: [_noTrackEventListKey],
      invalidationRanges: _patternInvalidationRangeCollector.size > 0
          ? _patternInvalidationRangeCollector.getRanges()
          : null,
    );

    if (_updateArrangements) {
      _compileAffectedArrangements();
    }

    reset();
  }

  void _schedulePatternCompile({
    required bool updateArrangements,
    bool debounce = false,
  }) {
    _updateArrangements = _updateArrangements || updateArrangements;

    if (debounce) {
      _automationCompileAction.execute();
      return;
    }

    if (_isImmediateCompileScheduled) {
      return;
    }

    _isImmediateCompileScheduled = true;

    Future.microtask(() {
      _isImmediateCompileScheduled = false;
      _flushScheduledPatternCompile();
    });
  }

  /// Compiles the entire pattern in the engine.
  void _compileInEngine() {
    if (!project.engine.isRunning) {
      return;
    }

    project.engine.sequencerApi.compilePattern(id);
  }
}
