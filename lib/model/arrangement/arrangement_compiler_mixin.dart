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

part of 'arrangement.dart';

mixin _ArrangementCompilerMixin on _ArrangementModel {
  void _recompileOnClipAddedOrRemoved(ClipModel? oldClip, ClipModel? newClip) {
    // If the engine is not running, then we don't need to worry about
    // sending this update. When the engine is started, it will recompile
    // all arrangements.
    if (!project.engine.isRunning) {
      return;
    }

    (int, int)? range;

    if (oldClip != null) {
      range = (
        oldClip.offset,
        oldClip.offset + oldClip.getWidthFromProject(project),
      );
    }

    if (newClip != null) {
      if (range == null) {
        range = (
          newClip.offset,
          newClip.offset + newClip.getWidthFromProject(project),
        );
      } else {
        range = (
          min(range.$1, newClip.offset),
          max(range.$2, newClip.offset + newClip.getWidthFromProject(project)),
        );
      }
    } else if (range == null) {
      throw Exception(
        'Both oldClip and newClip cannot be null at the same time.',
      );
    }

    String? patternIdFromOldClip;
    if (oldClip != null) {
      patternIdFromOldClip = oldClip.patternId;
      final pattern = project.sequence.patterns[oldClip.patternId];
      if (pattern != null) {
        for (final channelId in pattern.channelsWithContent) {
          _channelsToCompile.add(channelId);
          _invalidationRangeCollector.addRange(range.$1, range.$2);
        }
      }
    }

    if (newClip != null && patternIdFromOldClip != newClip.patternId) {
      final pattern = project.sequence.patterns[newClip.patternId];
      if (pattern != null) {
        for (final channelId in pattern.channelsWithContent) {
          _channelsToCompile.add(channelId);
          _invalidationRangeCollector.addRange(range.$1, range.$2);
        }
      }
    }

    _scheduleChannelsToCompile();
  }

  /// Rebuilds only modified clips in the engine.
  ///
  /// This is meant to be attached to the clips field changed listener above.
  void _recompileOnClipFieldChanged(
    Iterable<FieldAccessor> fieldAccessors,
    FieldOperation operation,
  ) {
    // If the engine is not running, then we don't need to worry about
    // sending this update. When the engine is started, it will recompile
    // all arrangements.
    if (!project.engine.isRunning) {
      return;
    }

    final clipAccessor = fieldAccessors.elementAt(2);

    // We need to mark the clip for rebuilding if anything changed,
    // besides trackId since that just tells it which row to render on.
    if (clipAccessor.fieldName != 'trackId') {
      final isOffsetChange = clipAccessor.fieldName == 'offset';
      final isTimeViewChange = clipAccessor.fieldName == 'timeView';

      final clipId = fieldAccessors.elementAt(1).key as Id;
      final clip = clips[clipId];
      if (clip != null) {
        final pattern = project.sequence.patterns[clip.patternId];
        if (pattern != null) {
          for (final channelId in pattern.channelsWithContent) {
            _channelsToCompile.add(channelId);

            final newWidth = clip.getWidthFromProject(project);

            _invalidationRangeCollector.addRange(
              clip.offset,
              clip.offset + newWidth,
            );

            if (isOffsetChange) {
              operation as RawFieldUpdate;
              _invalidationRangeCollector.addRange(
                operation.oldValueAs<int>(),
                operation.oldValueAs<int>() + newWidth,
              );
            }

            // There are three possible ways timeView can change:
            // 1. It was null and now it has a value.
            // 2. It was not null and is now null.
            // 3. Either its start or end property has changed.
            if (isTimeViewChange) {
              final isReplacement = fieldAccessors.length == 3;

              if (isReplacement) {
                operation as RawFieldUpdate;
                TimeViewModel? oldTimeView = operation
                    .oldValueAs<TimeViewModel?>();
                TimeViewModel? newTimeView = operation
                    .newValueAs<TimeViewModel?>();

                if (oldTimeView != null) {
                  _invalidationRangeCollector.addRange(
                    clip.offset,
                    clip.offset + oldTimeView.end - oldTimeView.start,
                  );
                }

                if (newTimeView != null) {
                  _invalidationRangeCollector.addRange(
                    clip.offset,
                    clip.offset + newTimeView.end - newTimeView.start,
                  );
                }
              } else {
                final timeViewAccessor = fieldAccessors.elementAt(3);

                if (timeViewAccessor.fieldName == 'start') {
                  final oldStart = (operation as RawFieldUpdate)
                      .oldValueAs<int>();
                  final newStart = operation.newValueAs<int>();

                  _invalidationRangeCollector.addRange(
                    clip.offset,
                    clip.offset +
                        (clip.timeView!.end - min(oldStart, newStart)),
                  );
                } else if (timeViewAccessor.fieldName == 'end') {
                  final oldEnd = (operation as RawFieldUpdate)
                      .oldValueAs<int>();
                  final newEnd = operation.newValueAs<int>();

                  final start = clip.timeView!.start;

                  final oldLength = oldEnd - start;
                  final newLength = newEnd - start;

                  _invalidationRangeCollector.addRange(
                    clip.offset + min(oldLength, newLength),
                    clip.offset + max(oldLength, newLength),
                  );
                }
              }
            }
          }
        }
      }
    }

    _scheduleChannelsToCompile();
  }

  final Set<Id> _channelsToCompile = {};
  final InvalidationRangeCollector _invalidationRangeCollector =
      InvalidationRangeCollector();
  bool _isScheduled = false;
  void _scheduleChannelsToCompile() {
    if (_isScheduled) {
      return;
    }

    _isScheduled = true;

    Future.microtask(() {
      _isScheduled = false;

      if (_channelsToCompile.isEmpty) {
        _invalidationRangeCollector.reset();
        return;
      }

      // If the engine is not running, we won't try to send anything.
      if (!project.engine.isRunning) {
        _channelsToCompile.clear();
        return;
      }

      project.engine.sequencerApi.compileArrangement(
        id,
        channelsToRebuild: _channelsToCompile.toList(),
        invalidationRanges: _invalidationRangeCollector.getRanges(),
      );

      _channelsToCompile.clear();
      _invalidationRangeCollector.reset();
    });
  }

  /// Compiles the entire arrangement in the engine.
  void _compileInEngine() {
    if (!project.engine.isRunning) {
      return;
    }

    project.engine.sequencerApi.compileArrangement(id);
  }
}
