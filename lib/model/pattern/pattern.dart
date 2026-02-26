/*
  Copyright (C) 2021 - 2026 Joshua Wade

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
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
// import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/widgets/basic/clip/clip_notes_render_cache.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:mobx/mobx.dart';

import '../shared/time_signature.dart';
import 'automation_lane.dart';
import 'note.dart';

part 'pattern.g.dart';

part 'package:anthem/widgets/basic/clip/clip_title_render_cache_mixin.dart';
part 'package:anthem/widgets/basic/clip/clip_notes_render_cache_mixin.dart';
part 'pattern_compiler_mixin.dart';

/// The primary container for events.
///
/// From a user-facing perspective, events in the arranger live inside clips.
/// But from an implementation perspective, clips are always just windows into
/// something else. This model, which we call a "pattern", is that "something
/// else". The pattern is the container that actually holds events for clips.
/// When you double-click on a clip with notes, for example, the piano roll
/// opens with a view directly into the pattern.
///
/// The purpose for this separation is two-fold:
///
/// First, clips provide the offset of this content in the viewer, and indicate
/// which track the content lives on. They also provide start and end points for
/// the content, allowing non-destructive resizing of the clip (e.g. chopping
/// audio as a use-case) without affecting the underlying content. This makes
/// clips an arranger-first concept. Patterns are the underlying content, and
/// are modified by editors that (mostly) do not care where or how that
/// container is instanced in the arranger.
///
/// Second, patterns and clips may be one-to-many. For each pattern, multiple
/// clips may exist in the arrangement. This allows for a number of powerful
/// use-cases, including:
/// - Content that loops can exist as multiple clips of a pattern with that
///   content, so that editing the pattern affects all instances of the clip
/// - The same notes can be placed on multiple tracks, where again, editing the
///   base content affects both clips
/// - Audio content can be sequenced in a pattern, and then instanced on
///   multiple tracks
///
/// Patterns can contain any of the following:
/// - Note events
/// - Audio events
/// - Automation events
/// - References to other clips
/// - For patterns on group tracks, references to clips on specific tracks
///
/// Note that free clips can technically contain any content as far as the
/// engine is concerned, but we only use this feature for enabling the audio
/// detail editor's functionality. This is important because UI render
/// optimization is a challenge, so we don't make an attempt to render for cases
/// we do not support. As an example, for a clip that points to a given pattern,
/// we only render notes that are in the notes list below, not notes that are in
/// the free clips list.
@AnthemModel.syncedModel()
class PatternModel extends _PatternModel
    with
        _$PatternModel,
        _$PatternModelAnthemModelMixin,
        _ClipTitleRenderCacheMixin,
        _ClipNotesRenderCacheMixin
/*_PatternCompilerMixin*/ {
  /// Action to tell the engine to send new loop points to the audio thread.
  late final _updateLoopPointsAction = MicrotaskDebouncedAction(() {
    final engine = project.engine;

    if (!engine.isRunning) {
      return;
    }

    project.engine.sequencerApi.updateLoopPoints(id);
  });

  /// Constructs a blank and invalid pattern.
  ///
  /// Used for serialization and deserialization.
  PatternModel() : super();

  /// Creates a [PatternModel].
  ///
  /// This is the primary entry point when creating a new pattern in the
  /// software. Note that JSON serialization and
  PatternModel.create({required super.name}) : super.create() {
    _init();
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
      // _channelsToCompile.addAll(channelsWithContent);
      // _schedulePatternCompile(false);

      // When notes are changed in the pattern, we need to:
      //   1. Update the clip notes render cache.
      //   2. Tell the engine to re-compile all relevant sequences.

      // Notes added or removed
      // onChange((b) => b.notes.anyElement, (e) {
      //   _recompileOnNotesAddedOrRemoved(
      //     e.fieldAccessors[1].key as String,
      //     e.operation.oldValue as NoteModel?,
      //     e.operation.newValue as NoteModel?,
      //   );
      // });

      // Note attributes changed
      // onChange((b) => b.notes.anyElement.anyField, (e) {
      //   _recompileOnNoteFieldChanged(e.fieldAccessors, e.operation);
      // });

      // When notes change, we also need to update the clip notes render cache
      // and the clip's default width.
      onChange((b) => b.notes.withDescendants, (e) {
        scheduleClipNotesRenderCacheUpdate();
        _clipAutoWidthUpdateAction.execute();
      });

      onChange((b) => b.automation.withDescendants, (e) {
        _clipAutoWidthUpdateAction.execute();
      });

      // When the pattern title is changed, we need to update the clip title
      // render cache.
      onChange((b) => b.name, (e) {
        updateClipTitleCache();
      });

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

  Iterable<String> get channelsWithContent => project.tracks.keys;
}

abstract class _PatternModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id id = getId();

  @anthemObservable
  String name = '';

  @anthemObservable
  AnthemColor color = AnthemColor(hue: 0);

  @anthemObservable
  AnthemObservableList<NoteModel> notes = AnthemObservableList();

  @anthemObservable
  AutomationLaneModel automation = AutomationLaneModel();

  @anthemObservable
  AnthemObservableList<TimeSignatureChangeModel> timeSignatureChanges =
      AnthemObservableList();

  @anthemObservable
  @hideFromSerialization
  LoopPointsModel? loopPoints;

  /// For deserialization. Use `PatternModel.create()` instead.
  _PatternModel();

  _PatternModel.create({required this.name}) {
    color = AnthemColor.randomHue();
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

    final lastNoteContent = notes.fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, note) => max(previousValue, (note.offset + note.length)),
    );

    final lastAutomationContent = max(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      automation.points.lastOrNull?.offset ?? 0,
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
    automation.observeAllChanges();

    return blockObservation(
      modelItems: [notes, automation],
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
