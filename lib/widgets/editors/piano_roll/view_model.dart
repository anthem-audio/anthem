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

class PianoRollTransientNote {
  final Id id;
  final int key;
  final double velocity;
  final int length;
  final int offset;
  final double pan;

  const PianoRollTransientNote({
    required this.id,
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
    required this.pan,
  });
}

class PianoRollNoteOverride {
  final int? key;
  final double? velocity;
  final int? length;
  final int? offset;
  final double? pan;

  const PianoRollNoteOverride({
    this.key,
    this.velocity,
    this.length,
    this.offset,
    this.pan,
  });

  bool get hasAnyValue =>
      key != null ||
      velocity != null ||
      length != null ||
      offset != null ||
      pan != null;
}

class PianoRollResolvedNote {
  final PianoRollRenderedNoteRef ref;
  final int key;
  final double velocity;
  final int length;
  final int offset;
  final double pan;
  final bool isSelected;
  final bool isPressed;
  final bool isHovered;
  final bool hasOverride;

  const PianoRollResolvedNote({
    required this.ref,
    required this.key,
    required this.velocity,
    required this.length,
    required this.offset,
    required this.pan,
    required this.isSelected,
    required this.isPressed,
    required this.isHovered,
    required this.hasOverride,
  });
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
  ObservableSet<Id> selectedNotes = ObservableSet();

  @observable
  Id? pressedNote;

  @observable
  Id? hoveredNote;

  @observable
  Id? pressedTransientNote;

  @observable
  Id? hoveredTransientNote;

  @observable
  ActiveNoteAttribute activeNoteAttribute = ActiveNoteAttribute.velocity;

  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  bool noteAttributeEditorOpen = true;

  final visibleNotes = CanvasAnnotationSet<PianoRollRenderedNoteRef>();
  final visibleResizeAreas = CanvasAnnotationSet<PianoRollRenderedNoteRef>();
  final transientNotes = ObservableMap<Id, PianoRollTransientNote>();
  final noteOverrides = ObservableMap<Id, PianoRollNoteOverride>();
  final selectedTransientNotes = ObservableSet<Id>();

  // These don't need to be observable, since they're just used during event
  // handling.
  Time cursorNoteLength = 96;
  double cursorNoteVelocity = 0.75;
  double cursorNotePan = 0;

  void clearTransientNoteState() {
    transientNotes.clear();
    selectedTransientNotes.clear();
    pressedTransientNote = null;
    hoveredTransientNote = null;
  }

  void clearNoteOverrides() {
    noteOverrides.clear();
  }

  void clearTransientPreviewState() {
    clearTransientNoteState();
    clearNoteOverrides();
  }

  PianoRollResolvedNote resolveRenderedRealNote(NoteModel note) {
    final override = noteOverrides[note.id];

    return PianoRollResolvedNote(
      ref: PianoRollRenderedNoteRef.real(note.id),
      key: override?.key ?? note.key,
      velocity: override?.velocity ?? note.velocity,
      length: override?.length ?? note.length,
      offset: override?.offset ?? note.offset,
      pan: override?.pan ?? note.pan,
      isSelected: selectedNotes.contains(note.id),
      isPressed: pressedNote == note.id,
      isHovered: hoveredNote == note.id,
      hasOverride: override?.hasAnyValue ?? false,
    );
  }

  PianoRollResolvedNote resolveRenderedTransientNote(
    PianoRollTransientNote note,
  ) {
    return PianoRollResolvedNote(
      ref: PianoRollRenderedNoteRef.transient(note.id),
      key: note.key,
      velocity: note.velocity,
      length: note.length,
      offset: note.offset,
      pan: note.pan,
      isSelected: selectedTransientNotes.contains(note.id),
      isPressed: pressedTransientNote == note.id,
      isHovered: hoveredTransientNote == note.id,
      hasOverride: false,
    );
  }

  PianoRollResolvedNote? resolveRenderedNoteByRef({
    required Iterable<NoteModel> realNotes,
    required PianoRollRenderedNoteRef ref,
  }) {
    if (ref.isTransient) {
      final transientNote = transientNotes[ref.id];
      if (transientNote == null) {
        return null;
      }

      return resolveRenderedTransientNote(transientNote);
    }

    final note = realNotes.firstWhereOrNull(
      (candidate) => candidate.id == ref.id,
    );
    if (note == null) {
      return null;
    }

    return resolveRenderedRealNote(note);
  }

  PianoRollResolvedNote? resolvePressedRenderedNote(
    Iterable<NoteModel> realNotes,
  ) {
    final transientNoteId = pressedTransientNote;
    if (transientNoteId != null) {
      final transientNote = transientNotes[transientNoteId];
      if (transientNote != null) {
        return resolveRenderedTransientNote(transientNote);
      }
    }

    final realNoteId = pressedNote;
    if (realNoteId == null) {
      return null;
    }

    final note = realNotes.firstWhereOrNull(
      (candidate) => candidate.id == realNoteId,
    );
    if (note == null) {
      return null;
    }

    return resolveRenderedRealNote(note);
  }

  List<PianoRollResolvedNote> resolveRenderedNotes(
    Iterable<NoteModel> realNotes,
  ) {
    final resolvedNotes = <PianoRollResolvedNote>[];
    final overriddenNotes = <PianoRollResolvedNote>[];

    for (final note in realNotes) {
      final resolvedNote = resolveRenderedRealNote(note);
      if (resolvedNote.hasOverride) {
        overriddenNotes.add(resolvedNote);
      } else {
        resolvedNotes.add(resolvedNote);
      }
    }

    resolvedNotes.addAll(overriddenNotes);

    for (final transientNote in transientNotes.values) {
      resolvedNotes.add(resolveRenderedTransientNote(transientNote));
    }

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
