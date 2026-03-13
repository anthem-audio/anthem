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

import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/widgets/basic/clip/clip_notes_render_cache.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import '../shared/time_signature.dart';
import 'automation_lane.dart';
import 'note.dart';

part 'pattern.g.dart';

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

  /// Constructs a blank and invalid pattern.
  ///
  /// Used for serialization and deserialization.
  PatternModel.uninitialized() : super();

  /// Creates a [PatternModel].
  ///
  /// This is the primary entry point when creating a new pattern in the
  /// software.
  PatternModel({
    required ProjectEntityIdAllocator idAllocator,
    required super.name,
  }) : super.create(id: idAllocator.allocateId()) {
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
      updateClipNotesRenderCache();

      _clipAutoWidthUpdateAction.execute();

      // Make sure the engine knows about this sequence when it is created, in
      // case it is created from project load or undo/redo
      _compileInEngine();

      // When notes are changed in the pattern, we need to:
      //   1. Update the clip notes render cache.
      //   2. Tell the engine to re-compile all relevant sequences.

      // Notes added or removed
      onChange((b) => b.notes.anyValue, (e) {
        _recompileOnNotesAddedOrRemoved(
          e.operation.oldValue as NoteModel?,
          e.operation.newValue as NoteModel?,
        );
      });

      // Note attributes changed
      onChange((b) => b.notes.anyValue.anyField, (e) {
        _recompileOnNoteFieldChanged(e);
      });

      // When notes change, we also need to update the clip notes render cache
      // and the clip's default width.
      onChange((b) => b.notes.withDescendants, (e) {
        scheduleClipNotesRenderCacheUpdate();
        _clipAutoWidthUpdateAction.execute();
      });

      // Preview note overrides are Dart-only changes that should still refresh
      // local rendering and width calculations throughout the UI.
      onChange((b) => b.noteOverrides.withDescendants, (e) {
        scheduleClipNotesRenderCacheUpdate();
        _clipAutoWidthUpdateAction.execute();
      });

      // Preview-only notes use the same local refresh path as overrides.
      //
      // These notes are not committed to the main pattern note list yet, but
      // they still need to appear everywhere that asks for the pattern's
      // effective note content.
      onChange((b) => b.previewNotes.withDescendants, (e) {
        scheduleClipNotesRenderCacheUpdate();
        _clipAutoWidthUpdateAction.execute();
      });

      onChange((b) => b.automation.withDescendants, (e) {
        _clipAutoWidthUpdateAction.execute();
      });

      // When the pattern title is changed, we need to update the clip title
      // render cache.
      onChange((b) => b.name, (e) {
        invalidateClipTitleAtlasEntry();
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
  Id id;

  @anthemObservable
  String name = '';

  @anthemObservable
  AnthemColor color = AnthemColor(hue: 0);

  @anthemObservable
  AnthemObservableMap<Id, NoteModel> notes = AnthemObservableMap();

  /// Live preview overrides for notes in this pattern.
  ///
  /// This is used for editor interactions that defer their real model write
  /// until the end of the gesture.
  ///
  /// Use [resolveNote] below in favor of direct access where possible.
  @anthemObservable
  @hideButAllowOnChange
  AnthemObservableMap<Id, PatternNoteOverrideModel> noteOverrides =
      AnthemObservableMap();

  /// Candidate notes that do not exist in [notes] yet, but are being added by
  /// the user as part of an in-progress action, such as clicking and dragging
  /// to add a note.
  @anthemObservable
  @hideButAllowOnChange
  AnthemObservableMap<Id, NoteModel> previewNotes = AnthemObservableMap();

  @anthemObservable
  AutomationLaneModel automation = AutomationLaneModel();

  @anthemObservable
  AnthemObservableList<TimeSignatureChangeModel> timeSignatureChanges =
      AnthemObservableList();

  @anthemObservable
  @hideFromSerialization
  LoopPointsModel? loopPoints;

  /// For deserialization. Use `PatternModel()` instead.
  _PatternModel() : id = '';

  _PatternModel.create({required this.id, required this.name}) {
    color = AnthemColor.randomHue();
    timeSignatureChanges = AnthemObservableList();
  }

  /// Returns the effective values for [note], including any active preview
  /// override for that note ID.
  ResolvedPatternNote resolveNote(
    NoteModel note, {
    bool isPreviewOnly = false,
  }) {
    final noteOverride = noteOverrides[note.id];

    return ResolvedPatternNote(
      id: note.id,
      key: noteOverride?.key ?? note.key,
      velocity: noteOverride?.velocity ?? note.velocity,
      length: noteOverride?.length ?? note.length,
      offset: noteOverride?.offset ?? note.offset,
      pan: noteOverride?.pan ?? note.pan,
      hasOverride: noteOverride?.hasAnyValue ?? false,
      isPreviewOnly: isPreviewOnly,
    );
  }

  /// Returns the effective values for the note with [noteId], or null if the
  /// note does not exist in either preview or committed state.
  ResolvedPatternNote? resolveNoteById(Id noteId) {
    final note = notes[noteId];
    if (note != null) {
      return resolveNote(note);
    }

    final previewNote = previewNotes[noteId];
    if (previewNote != null) {
      return resolveNote(previewNote, isPreviewOnly: true);
    }

    return null;
  }

  /// Returns the preview-only note with [noteId], if it exists.
  NoteModel? getPreviewNoteById(Id noteId) {
    return previewNotes[noteId];
  }

  /// Iterates the effective note content for this pattern.
  ///
  /// Committed notes are yielded first in stored order, with preview overrides
  /// applied. Preview-only notes are then appended after. This allows a
  /// renderer to just draw in the order they are received.
  Iterable<ResolvedPatternNote> getResolvedNotes() sync* {
    for (final note in notes.values) {
      yield resolveNote(note);
    }

    for (final note in previewNotes.values) {
      yield resolveNote(note, isPreviewOnly: true);
    }
  }

  /// Merges preview override values into the existing override for [noteId].
  ///
  /// Unspecified fields keep their current preview values. This allows
  /// separate interactions to layer preview changes across different note
  /// attributes without re-reading call-site state.
  void setNoteOverride({
    required Id noteId,
    int? key,
    double? velocity,
    int? length,
    int? offset,
    double? pan,
  }) {
    final existingOverride = noteOverrides[noteId];

    final noteOverride = PatternNoteOverrideModel(
      key: key ?? existingOverride?.key,
      velocity: velocity ?? existingOverride?.velocity,
      length: length ?? existingOverride?.length,
      offset: offset ?? existingOverride?.offset,
      pan: pan ?? existingOverride?.pan,
    );

    if (!noteOverride.hasAnyValue) {
      noteOverrides.remove(noteId);
      return;
    }

    noteOverrides[noteId] = noteOverride;
  }

  /// Adds a preview-only note that is not yet committed to [notes].
  void addPreviewNote(NoteModel note) {
    previewNotes[note.id] = note;
  }

  /// Updates a preview-only note in place.
  void updatePreviewNote({
    required Id noteId,
    int? key,
    double? velocity,
    int? length,
    int? offset,
    double? pan,
  }) {
    final previewNote = getPreviewNoteById(noteId);
    if (previewNote == null) {
      throw StateError('Preview note $noteId was not found.');
    }

    if (key != null) {
      previewNote.key = key;
    }

    if (velocity != null) {
      previewNote.velocity = velocity;
    }

    if (length != null) {
      previewNote.length = length;
    }

    if (offset != null) {
      previewNote.offset = offset;
    }

    if (pan != null) {
      previewNote.pan = pan;
    }
  }

  /// Updates the effective preview state for [noteId].
  void setResolvedNotePreview({
    required Id noteId,
    int? key,
    double? velocity,
    int? length,
    int? offset,
    double? pan,
  }) {
    final previewNote = getPreviewNoteById(noteId);
    if (previewNote != null) {
      updatePreviewNote(
        noteId: noteId,
        key: key,
        velocity: velocity,
        length: length,
        offset: offset,
        pan: pan,
      );
      return;
    }

    setNoteOverride(
      noteId: noteId,
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );
  }

  void clearNoteOverrides() {
    noteOverrides.clear();
  }

  void clearPreviewNotes() {
    previewNotes.clear();
  }

  void removePreviewNoteById(Id noteId) {
    previewNotes.remove(noteId);
  }

  void clearNotePreviews() {
    noteOverrides.clear();
    previewNotes.clear();
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

    final lastNoteContent = getResolvedNotes().fold<int>(
      ticksPerBar * barMultiple * minPaddingInBarMultiples,
      (previousValue, note) => max(previousValue, note.offset + note.length),
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
    noteOverrides.observeAllChanges();
    previewNotes.observeAllChanges();
    automation.observeAllChanges();

    return blockObservation(
      modelItems: [notes, noteOverrides, previewNotes, automation],
      block: () => getWidth(barMultiple: 4, minPaddingInBarMultiples: 4),
    );
  }

  @hide
  void invalidateClipTitleAtlasEntry() {
    final sequence = getFirstAncestorOfType<SequencerModel>();
    sequence.invalidateClipTitleAtlasEntryForPattern(id);
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
