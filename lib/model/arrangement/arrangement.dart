/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/model/shared/loop_points.dart';
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
  ArrangementModel.uninitialized() : super(name: '', id: '');

  ArrangementModel.create({required super.name, required super.id})
    : super.create() {
    _init();
  }

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
    onModelFirstAttached(() {
      _compileInEngine();

      updateViewWidthAction.execute();

      onChange(
        (b) => b.clips.anyValue.multiple([
          (b) => b.offset,
          (b) => b.patternId,
          (b) => b.timeView.withDescendants,
        ]),
        (e) {
          _recompileOnClipFieldChanged(e.fieldAccessors, e.operation);
        },
      );

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
  AnthemObservableMap<Id, ClipModel> clips = AnthemObservableMap();

  @anthemObservable
  @hideFromSerialization
  LoopPointsModel? loopPoints;

  _ArrangementModel({required this.name, required this.id}) : super();

  _ArrangementModel.create({required this.name, required this.id}) : super();

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
