/*
  Copyright (C) 2023 Joshua Wade

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
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

part 'view_model.g.dart';

enum ActiveNoteAttribute {
  velocity(bottom: 0, baseline: 0, top: 127),
  pan(bottom: -127, baseline: 0, top: 127);

  const ActiveNoteAttribute({
    required this.bottom,
    required this.baseline,
    required this.top,
  });

  final int bottom;
  final int baseline;
  final int top;
}

// ignore: library_private_types_in_public_api
class PianoRollViewModel = _PianoRollViewModel with _$PianoRollViewModel;

abstract class _PianoRollViewModel with Store {
  _PianoRollViewModel({
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.timeView,
  });

  @observable
  double keyHeight;

  @observable
  double keyValueAtTop;

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
  ActiveNoteAttribute activeNoteAttribute = ActiveNoteAttribute.velocity;

  @observable
  EditorTool tool = EditorTool.pencil;

  final visibleNotes = CanvasAnnotationSet<({Id id})>();
  final visibleResizeAreas = CanvasAnnotationSet<({Id id})>();

  // These don't need to be observable, since they're just used during event
  // handling.
  Time cursorNoteLength = 96;
  int cursorNoteVelocity = 128 * 3 ~/ 4;
  int cursorNotePan = 0;

  /// Calculates the note and resize handle under the cursor, if there is one.
  ({
    CanvasAnnotation<({Id id})>? note,
    CanvasAnnotation<({Id id})>? resizeHandle,
  }) getContentUnderCursor(Offset pos) {
    final noteUnderCursor = visibleNotes.hitTest(pos);
    final resizeHandleUnderCursor = visibleResizeAreas
        .hitTestAll(pos)
        // We only report a resize handle if the cursor is also over the
        // associated note, or if the cursor is over no note. This makes the
        // behavior for note resizing a bit more predictable, as it then doesn't
        // depend on the Z-ordering of notes for notes that are right next to
        // each other.
        .firstWhereOrNull((element) =>
            noteUnderCursor == null ||
            element.metadata.id == noteUnderCursor.metadata.id);
    return (note: noteUnderCursor, resizeHandle: resizeHandleUnderCursor);
  }
}
