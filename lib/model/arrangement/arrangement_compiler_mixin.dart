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
  /// Rebuilds only modified clips in the engine.
  ///
  /// This is meant to be attached to the clips field changed listener above.
  void _recompileModifiedClips(
    Iterable<FieldAccessor> fieldAccessors,
    FieldOperation operation,
  ) {
    // If the engine is not running, then we don't need to worry about
    // sending this update. When the engine is started, it will recompile
    // all arrangements.
    if (!project.engine.isRunning) {
      return;
    }

    // This means we're adding, replacing or removing a clip.
    if (fieldAccessors.length == 1) {
      final oldClip = switch (operation) {
        RawFieldUpdate() => operation.oldValueAs<ClipModel>(),
        ListInsert() => null,
        ListRemove() => operation.removedValueAs<ClipModel>(),
        ListUpdate() => operation.oldValueAs<ClipModel>(),
        MapPut() => operation.oldValueAs<ClipModel?>(),
        MapRemove() => operation.removedValueAs<ClipModel>(),
      };

      final newClip = switch (operation) {
        RawFieldUpdate() => operation.newValueAs<ClipModel>(),
        ListInsert() => operation.valueAs<ClipModel>(),
        ListRemove() => null,
        ListUpdate() => operation.newValueAs<ClipModel>(),
        MapPut() => operation.newValueAs<ClipModel?>(),
        MapRemove() => null,
      };

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
            max(
              range.$2,
              newClip.offset + newClip.getWidthFromProject(project),
            ),
          );
        }
      } else if (range == null) {
        throw Exception(
          'Both oldClip and newClip cannot be null at the same time.',
        );
      }

      if (oldClip != null) {
        final pattern = project.sequence.patterns[oldClip.patternId];
        if (pattern != null) {
          for (final channelId in pattern.channelsWithContent) {
            _channelsToCompile.add(channelId);
            _invalidationRangeCollector.addRange(range.$1, range.$2);
          }
        }
      }

      if (newClip != null) {
        final pattern = project.sequence.patterns[newClip.patternId];
        if (pattern != null) {
          for (final channelId in pattern.channelsWithContent) {
            _channelsToCompile.add(channelId);
            _invalidationRangeCollector.addRange(range.$1, range.$2);
          }
        }
      }
    }

    final clipAccessor = fieldAccessors.elementAtOrNull(1);

    // This means we're changing a property of a clip.
    if (clipAccessor != null) {
      // We need to mark the clip for rebuilding if anything changed,
      // besides trackId since that just tells it which row to render on.
      if (clipAccessor.fieldName != 'trackId') {
        final clipId = fieldAccessors.first.key as Id;
        final clip = clips[clipId];
        if (clip != null) {
          final pattern = project.sequence.patterns[clip.patternId];
          if (pattern != null) {
            for (final channelId in pattern.channelsWithContent) {
              _channelsToCompile.add(channelId);
              _invalidationRangeCollector.addRange(
                clip.offset,
                clip.offset + clip.getWidthFromProject(project),
              );
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
