/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/main.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/widgets/basic/clip/clip_notes_render_cache.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:mobx/mobx.dart';

import '../shared/time_signature.dart';
import 'automation_lane.dart';
import 'note.dart';

part 'pattern.g.dart';

part 'package:anthem/widgets/basic/clip/clip_title_render_cache_mixin.dart';
part 'package:anthem/widgets/basic/clip/clip_notes_render_cache_mixin.dart';
part 'pattern_compiler_mixin.dart';

@AnthemModel.syncedModel()
class PatternModel extends _PatternModel
    with
        _$PatternModel,
        _$PatternModelAnthemModelMixin,
        _ClipTitleRenderCacheMixin,
        _ClipNotesRenderCacheMixin,
        _PatternCompilerMixin {
  /// Action to tell the engine to send new loop points to the audio thread.
  late final _updateLoopPointsAction = MicrotaskDebouncedAction(() {
    final engine = project.engine;

    if (!engine.isRunning) {
      return;
    }

    project.engine.sequencerApi.updateLoopPoints(id);
  });

  PatternModel() : super();

  PatternModel.create({required super.name}) : super.create() {
    _init();

    onModelFirstAttached(() {
      // I had a todo comment to remove this, but I have no idea why, so I'm
      // leaving this comment instead. ¯\_(ツ)_/¯
      for (final generator in project.generators.values.where(
        (generator) => generator.generatorType == GeneratorType.automation,
      )) {
        automationLanes[generator.id] = AutomationLaneModel();
      }
    });
  }

  factory PatternModel.fromJson(Map<String, dynamic> json) {
    final result = _$PatternModelAnthemModelMixin.fromJson(json);
    result._init();
    return result;
  }

  void _init() {
    onModelFirstAttached(() {
      incrementClipUpdateSignal = Action(() {
        clipNotesUpdateSignal.value =
            (clipNotesUpdateSignal.value + 1) % 0xFFFFFFFF;
      });

      // Initialize render caches
      updateClipTitleCache();
      updateClipNotesRenderCache();

      _clipAutoWidthUpdateAction.execute();

      // Make sure the engine knows about this sequence when it is created, in
      // case it is created from project load or undo/redo
      _channelsToCompile.addAll(channelsWithContent);
      _schedulePatternCompile(false);

      // When notes are changed in the pattern, we need to:
      //   1. Update the clip notes render cache.
      //   2. Tell the engine to re-compile all relevant sequences.
      notes.addFieldChangedListener((fieldAccessors, operation) {
        scheduleClipNotesRenderCacheUpdate();
        _clipAutoWidthUpdateAction.execute();

        _recompileModifiedNotes(fieldAccessors, operation);
      });

      automationLanes.addFieldChangedListener((fieldAccessors, operation) {
        _clipAutoWidthUpdateAction.execute();
      });

      // When the pattern title is changed, we need to update the clip title
      // render cache.
      addFieldChangedListener((fieldAccessors, operation) {
        // The notes field might be entirely replaced instead of just updated.
        // In this case we also need to update the clip notes render cache.
        if (fieldAccessors.elementAtOrNull(1) == null &&
            fieldAccessors.first.fieldName == 'notes') {
          scheduleClipNotesRenderCacheUpdate();
        } else if (fieldAccessors.first.fieldName == 'name') {
          updateClipTitleCache();
        } else if (fieldAccessors.first.fieldName == 'loopPoints') {
          _updateLoopPointsAction.execute();
        }
      });
    });
  }

  Iterable<String> get channelsWithContent =>
      notes.keys.followedBy(automationLanes.keys);
}

abstract class _PatternModel with Store, AnthemModelBase {
  Id id = getId();

  @anthemObservable
  String name = '';

  @anthemObservable
  AnthemColor color = AnthemColor(hue: 0);

  /// The ID here is channel ID `Map<ChannelID, List<NoteModel>>`
  @anthemObservable
  AnthemObservableMap<Id, AnthemObservableList<NoteModel>> notes =
      AnthemObservableMap();

  /// The ID here is channel ID
  @anthemObservable
  AnthemObservableMap<Id, AutomationLaneModel> automationLanes =
      AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<TimeSignatureChangeModel> timeSignatureChanges =
      AnthemObservableList();

  @anthemObservable
  @hideFromSerialization
  LoopPointsModel? loopPoints;

  /// For deserialization. Use `PatternModel.create()` instead.
  _PatternModel();

  _PatternModel.create({required this.name}) {
    color = AnthemColor(hue: 0, saturationMultiplier: 0);
    timeSignatureChanges = AnthemObservableList();
  }

  /// Gets the time position of the end of the last item in this pattern
  /// (note, audio clip, automation point), rounded upward to the nearest
  /// `barMultiple` bars.
  int getWidth({int barMultiple = 1, int minPaddingInBarMultiples = 1}) {
    final ticksPerBarDouble =
        project.sequence.ticksPerQuarter /
        (project.sequence.defaultTimeSignature.denominator / 4) *
        project.sequence.defaultTimeSignature.numerator;
    final ticksPerBar = ticksPerBarDouble.round();

    // It should not be possible for ticksPerBar to be fractional.
    // ticksPerQuarter must be divisible by every possible value of
    // (denominator / 4). Denominator can be [1, 2, 4, 8, 16, 32]. Therefore,
    // ticksPerQuarter must be divisible by [0.25, 0.5, 1, 2, 4, 8].
    assert(ticksPerBarDouble == ticksPerBar);

    final lastNoteContent = notes.values
        .expand((e) => e)
        .fold<int>(
          ticksPerBar * barMultiple * minPaddingInBarMultiples,
          (previousValue, note) =>
              max(previousValue, (note.offset + note.length)),
        );

    final lastAutomationContent = automationLanes.values.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, automationLane) =>
          max(previousValue, automationLane.points.lastOrNull?.offset ?? 0),
    );

    final lastContent = max(lastNoteContent, lastAutomationContent);

    return (max(lastContent, 1) / (ticksPerBar * barMultiple)).ceil() *
        ticksPerBar *
        barMultiple;
  }

  @computed
  int get lastContent {
    // Observing this operation is incredibly expensive for some reason, so we
    // prevent detailed observation and just observe the whole thing.

    notes.observeAllChanges();
    automationLanes.observeAllChanges();

    return blockObservation(
      modelItems: [notes, automationLanes],
      block: () => getWidth(barMultiple: 4, minPaddingInBarMultiples: 4),
    );
  }

  /// The width that a clip will take on if it has no time view.
  ///
  /// This must be updated whenever the pattern content changes. This is cached
  /// so that the arranger doesn't have to recalculate this for every changed
  /// clip on every edit.
  @anthemObservable
  @hide
  late int clipAutoWidth = getWidth();

  @hide
  late final MicrotaskDebouncedAction _clipAutoWidthUpdateAction =
      MicrotaskDebouncedAction(() {
        final newClipAutoWidth = getWidth();

        final arrangements = project.sequence.arrangements.values.toList();

        // If the clip size changed, it may be the newest last clip in any
        // arrangement, so we need to resize all the arrangements.
        if (newClipAutoWidth != clipAutoWidth) {
          for (final arrangement in arrangements) {
            arrangement.updateViewWidthAction.execute();
          }
        }

        clipAutoWidth = newClipAutoWidth;
      });

  @computed
  bool get hasTimeMarkers {
    return timeSignatureChanges.isNotEmpty;
  }
}
