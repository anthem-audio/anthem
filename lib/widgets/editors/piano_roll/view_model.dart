/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

part 'view_model.g.dart';

enum ActiveNoteAttribute {
  velocity(bottom: 0, baseline: 0, top: 1),
  pan(bottom: -1, baseline: 0, top: 1);

  const ActiveNoteAttribute({
    required this.bottom,
    required this.baseline,
    required this.top,
  });

  final int bottom;
  final int baseline;
  final int top;
}

class PianoRollRenderedNoteRef {
  final Id id;
  final bool isTransient;

  const PianoRollRenderedNoteRef.real(this.id) : isTransient = false;
  const PianoRollRenderedNoteRef.transient(this.id) : isTransient = true;

  Id? get realNoteId => isTransient ? null : id;

  @override
  bool operator ==(Object other) {
    return other is PianoRollRenderedNoteRef &&
        other.id == id &&
        other.isTransient == isTransient;
  }

  @override
  int get hashCode => Object.hash(id, isTransient);
}

// ignore: library_private_types_in_public_api
class PianoRollViewModel = _PianoRollViewModel with _$PianoRollViewModel;

abstract class _PianoRollViewModel with Store {
  _PianoRollViewModel({
    required this.keyHeight,
    required double keyValueAtTop,
    required this.timeView,
  }) : keyValueAtTopRaw = keyValueAtTop;

  @observable
  double keyHeight;

  @observable
  double keyValueAtTopRaw;

  double get keyValueAtTop => keyValueAtTopRaw;
  set keyValueAtTop(double value) {
    keyValueAtTopRaw = value;
    // Don't snap by default
    keyValueAtTopAnimationShouldSnap = false;
  }

  @observable
  bool keyValueAtTopAnimationShouldSnap = false;

  @observable
  TimeRange timeView;

  @observable
  Rectangle<double>? selectionBox;

  @observable
  /// Selected note IDs across both committed notes and preview-only notes.
  ///
  /// Preview notes inherit their IDs when they are committed, so selection can
  /// follow them across that boundary without a separate transient selection
  /// structure.
  ObservableSet<Id> selectedNotes = ObservableSet();

  @observable
  Id? pressedNote;

  @observable
  Id? hoveredNote;

  @observable
  ActiveNoteAttribute activeNoteAttribute = ActiveNoteAttribute.velocity;

  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  bool noteAttributeEditorOpen = true;

  final visibleNotes = CanvasAnnotationSet<PianoRollRenderedNoteRef>();
  final visibleResizeAreas = CanvasAnnotationSet<PianoRollRenderedNoteRef>();

  // These don't need to be observable, since they're just used during event
  // handling.
  Time cursorNoteLength = 96;
  double cursorNoteVelocity = 0.75;
  double cursorNotePan = 0;

  void clearTransientNoteState() {
    pressedNote = null;
    hoveredNote = null;
  }

  /// Clears transient interaction state that should never outlive a gesture.
  ///
  /// Selection cleanup for preview-only note IDs happens at the controller
  /// layer, where the active pattern is available and we can tell which IDs
  /// are about to disappear when preview notes are cleared.
  void clearTransientPreviewState() {
    clearTransientNoteState();
  }

  PianoRollRenderedNoteRef renderedRefFor(ResolvedPatternNote note) {
    return note.isPreviewOnly
        ? PianoRollRenderedNoteRef.transient(note.id)
        : PianoRollRenderedNoteRef.real(note.id);
  }

  bool isNoteSelected(ResolvedPatternNote note) =>
      selectedNotes.contains(note.id);

  bool isNotePressed(ResolvedPatternNote note) => pressedNote == note.id;

  bool isNoteHovered(ResolvedPatternNote note) => hoveredNote == note.id;

  ResolvedPatternNote? resolveRenderedNoteByRef({
    required PatternModel pattern,
    required PianoRollRenderedNoteRef ref,
  }) {
    final note = pattern.resolveNoteById(ref.id);
    if (note == null) {
      return null;
    }

    if (note.isPreviewOnly != ref.isTransient) {
      return null;
    }

    return note;
  }

  ResolvedPatternNote? resolvePressedRenderedNote(PatternModel pattern) {
    final pressedNoteId = pressedNote;
    if (pressedNoteId == null) {
      return null;
    }

    final note = pattern.resolveNoteById(pressedNoteId);
    if (note == null) {
      return null;
    }

    return note;
  }

  List<ResolvedPatternNote> resolveRenderedNotes(PatternModel pattern) {
    final resolvedNotes = <ResolvedPatternNote>[];
    final overriddenNotes = <ResolvedPatternNote>[];
    final previewOnlyNotes = <ResolvedPatternNote>[];

    for (final note in pattern.getResolvedNotes()) {
      if (note.isPreviewOnly) {
        previewOnlyNotes.add(note);
      } else if (note.hasOverride) {
        overriddenNotes.add(note);
      } else {
        resolvedNotes.add(note);
      }
    }

    // Notes painted later appear above earlier notes and win hit tests. Preview
    // notes should therefore sit on top, with overridden committed notes above
    // plain committed notes.
    resolvedNotes.addAll(overriddenNotes);
    resolvedNotes.addAll(previewOnlyNotes);

    return resolvedNotes;
  }

  /// Calculates the note and resize handle under the cursor, if there is one.
  ({
    CanvasAnnotation<PianoRollRenderedNoteRef>? note,
    CanvasAnnotation<PianoRollRenderedNoteRef>? resizeHandle,
  })
  getContentUnderCursor(Offset pos) {
    final noteUnderCursor = visibleNotes.hitTest(pos);
    final resizeHandleUnderCursor = visibleResizeAreas
        .hitTestAll(pos)
        // We only report a resize handle if the cursor is also over the
        // associated note, or if the cursor is over no note. This makes the
        // behavior for note resizing a bit more predictable, as it then doesn't
        // depend on the Z-ordering of notes for notes that are right next to
        // each other.
        .firstWhereOrNull(
          (element) =>
              noteUnderCursor == null ||
              element.metadata == noteUnderCursor.metadata,
        );
    return (note: noteUnderCursor, resizeHandle: resizeHandleUnderCursor);
  }
}
