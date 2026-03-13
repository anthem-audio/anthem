/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'dart:math';

import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'clip.dart';

part 'arrangement_compiler_mixin.dart';

part 'arrangement.g.dart';

@AnthemModel.syncedModel()
class ArrangementModel extends _ArrangementModel
    with
        _$ArrangementModel,
        _$ArrangementModelAnthemModelMixin,
        _ArrangementCompilerMixin {
  ArrangementModel({
    required ProjectEntityIdAllocator idAllocator,
    required super.name,
  }) : super.create(id: idAllocator.allocateId()) {
    _init();
  }

  ArrangementModel.uninitialized() : super(name: '', id: '');

  factory ArrangementModel.fromJson(Map<String, dynamic> json) {
    final arrangement = _$ArrangementModelAnthemModelMixin.fromJson(json);
    arrangement._init();
    return arrangement;
  }

  /// Action to tell the engine to send new loop points to the audio thread.
  late final _updateLoopPointsAction = MicrotaskDebouncedAction(() {
    final engine = project.engine;

    if (!engine.isRunning) {
      return;
    }

    project.engine.sequencerApi.updateLoopPoints(id);
  });

  void _init() {
    _rebuildPatternClipReferenceCounts();

    // Keep the pattern usage cache in sync when clips are inserted, replaced,
    // or removed from the arrangement.
    onChange((b) => b.clips.anyValue, (e) {
      final oldClip = e.operation.oldValue as ClipModel?;
      final newClip = e.operation.newValue as ClipModel?;

      if (oldClip != null) {
        _decrementPatternClipReferenceCount(oldClip.patternId);
      }

      if (newClip != null) {
        _incrementPatternClipReferenceCount(newClip.patternId);
      }
    });

    // Keep the pattern usage cache in sync when an existing clip is retargeted
    // to a different pattern.
    onChange((b) => b.clips.anyValue.patternId, (e) {
      final oldPatternId = e.operation.oldValue as Id?;
      final newPatternId = e.operation.newValue as Id?;

      // Clip add/remove is handled by the clips.anyValue observer above.
      if (oldPatternId == null || newPatternId == null) {
        return;
      }

      if (oldPatternId == newPatternId) {
        return;
      }

      _decrementPatternClipReferenceCount(oldPatternId);
      _incrementPatternClipReferenceCount(newPatternId);
    });

    onModelFirstAttached(() {
      _compileInEngine();

      updateViewWidthAction.execute();

      // Recompile affected engine clip data when clip timing or source pattern
      // fields change.
      onChange(
        (b) => b.clips.anyValue.multiple([
          (b) => b.offset,
          (b) => b.trackId,
          (b) => b.patternId,
          (b) => b.timeView.withDescendants,
        ]),
        (e) {
          _recompileOnClipFieldChanged(e);
        },
      );

      // Recompile engine clip data when clips are added or removed.
      onChange((b) => b.clips.anyValue, (e) {
        _recompileOnClipAddedOrRemoved(
          e.operation.oldValue as ClipModel?,
          e.operation.newValue as ClipModel?,
        );
      });

      // We need to update viewWidth whenever clips or relevant clip properties
      // change.
      onChange(
        (b) => b.multiple([
          // Changes to the clips map itself
          (b) => b.clips.anyValue,

          // Changes to clip properties that affect arrangement width
          (b) => b.clips.anyValue.multiple([
            (b) => b.offset,
            (b) => b.patternId,
            (b) => b.timeView.withDescendants,
          ]),
        ]),
        (e) {
          updateViewWidthAction.execute();
        },
      );

      // After updating loop points in the model, we inform the engine.
      //
      // We don't have a detailed model change observation system in the engine,
      // so this is a simple way to allow the engine to perform necessary
      // side-effects.
      onChange((b) => b.loopPoints.withDescendants, (e) {
        _updateLoopPointsAction.execute();
      });
    });
  }
}

abstract class _ArrangementModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id id;

  @anthemObservable
  String name;

  @anthemObservable
  AnthemObservableMap<Id, ClipModel> clips = .new();

  @anthemObservable
  AnthemObservableList<TimeSignatureChangeModel> timeSignatureChanges = .new();

  @anthemObservable
  @hideFromSerialization
  LoopPointsModel? loopPoints;

  /// Non-serialized cache of clip reference counts per pattern for this
  /// arrangement.
  ///
  /// The key is a pattern ID, and the value is the number of clips in this
  /// arrangement that reference that pattern ID.
  @hide
  final Map<Id, int> patternClipReferenceCounts = {};

  _ArrangementModel({required this.name, required this.id}) : super();

  _ArrangementModel.create({required this.name, required this.id}) : super();

  @hide
  int getPatternClipReferenceCount(Id patternId) {
    return patternClipReferenceCounts[patternId] ?? 0;
  }

  @hide
  void _rebuildPatternClipReferenceCounts() {
    patternClipReferenceCounts.clear();
    for (final clip in clips.values) {
      _incrementPatternClipReferenceCount(clip.patternId);
    }
  }

  @hide
  void _incrementPatternClipReferenceCount(Id patternId) {
    patternClipReferenceCounts[patternId] =
        (patternClipReferenceCounts[patternId] ?? 0) + 1;
  }

  @hide
  void _decrementPatternClipReferenceCount(Id patternId) {
    final currentCount = patternClipReferenceCounts[patternId];
    if (currentCount == null) {
      return;
    }

    if (currentCount <= 1) {
      patternClipReferenceCounts.remove(patternId);
      return;
    }

    patternClipReferenceCounts[patternId] = currentCount - 1;
  }

  /// Gets the time position of the end of the last clip in this arrangement,
  /// rounded upward to the nearest `barMultiple` bars.
  int getWidth({int barMultiple = 4, int minPaddingInBarMultiples = 4}) {
    final defaultTimeSignature =
        getFirstAncestorOfType<SequencerModel>().defaultTimeSignature;

    final ticksPerBarDouble =
        project.sequence.ticksPerQuarter /
        (defaultTimeSignature.denominator / 4) *
        defaultTimeSignature.numerator;

    final ticksPerBar = ticksPerBarDouble.round();

    // It should not be possible for ticksPerBar to be fractional.
    // ticksPerQuarter must be divisible by every possible value of
    // (denominator / 4). Denominator can be [1, 2, 4, 8, 16, 32]. Therefore,
    // ticksPerQuarter must be divisible by [0.25, 0.5, 1, 2, 4, 8].
    assert(ticksPerBar == ticksPerBarDouble);

    final lastContent = clips.values.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, clip) =>
          max(previousValue, clip.offset + clip.getWidthFromProject(project)),
    );

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }

  /// Width of the arrangement in ticks, with some buffer at the end, based on
  /// the width of the content in the arrangement.
  ///
  /// This must be updated whenever any clip is added or removed, or if its
  /// position or size changes.
  @anthemObservable
  @hide
  late int viewWidth = getWidth();

  /// A debounced action to update [viewWidth].
  ///
  /// This action must be run when clips are changed.
  ///
  /// MobX provides us a way to trigger this on the relevant model changes;
  /// however, it is at least a full order of magnitude slower. Since this runs
  /// very often, we do it manually instead.
  ///
  /// Anthem has a system for observing model changes (see generated onChange
  /// method for models), and we use this to trigger the action.
  @hide
  late final MicrotaskDebouncedAction updateViewWidthAction =
      MicrotaskDebouncedAction(() {
        viewWidth = getWidth();
      });
}
