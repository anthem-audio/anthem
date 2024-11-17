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
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

part 'view_model.g.dart';

// ignore: library_private_types_in_public_api
class ArrangerViewModel = _ArrangerViewModel with _$ArrangerViewModel;

enum ResizeAreaType { start, end }

abstract class _ArrangerViewModel with Store {
  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  TimeRange timeView;

  @observable
  double baseTrackHeight;

  /// Per-track modifier that is multiplied by baseTrackHeight and clamped to
  /// get the actual height for each track
  @observable
  ObservableMap<Id, double> trackHeightModifiers;

  /// Vertical scroll position, in pixels.
  @observable
  double verticalScrollPosition = 0;

  /// Current pattern that will be placed when the user places a pattern.
  @observable
  Id? cursorPattern;

  /// Time range for cursor pattern.
  @observable
  TimeViewModel? cursorTimeRange;

  @observable
  Rectangle<double>? selectionBox;

  @observable
  ObservableSet<Id> selectedClips = ObservableSet();

  @observable
  Id? pressedClip;

  final visibleClips = CanvasAnnotationSet<({Id id})>();
  final visibleResizeAreas =
      CanvasAnnotationSet<({Id id, ResizeAreaType type})>();

  _ArrangerViewModel({
    required this.baseTrackHeight,
    required this.trackHeightModifiers,
    required this.timeView,
  });

  // Total height of the entire scrollable region
  @computed
  double get scrollAreaHeight =>
      getScrollAreaHeight(baseTrackHeight, trackHeightModifiers);

  /// Calculates the clip and resize handle under the cursor, if there is one.
  ({
    CanvasAnnotation<({Id id})>? clip,
    CanvasAnnotation<({Id id, ResizeAreaType type})>? resizeHandle,
  }) getContentUnderCursor(Offset pos) {
    final clipUnderCursor = visibleClips.hitTest(pos);
    final resizeHandleUnderCursor = visibleResizeAreas
        .hitTestAll(pos)
        // We only report a resize handle if the cursor is also over the
        // associated clip, or if the cursor is over no clip. This makes the
        // behavior for clip resizing a bit more predictable, as it then doesn't
        // depend on the Z-ordering of clips for clips that are right next to
        // each other.
        .firstWhereOrNull((element) =>
            clipUnderCursor == null ||
            element.metadata.id == clipUnderCursor.metadata.id);
    return (clip: clipUnderCursor, resizeHandle: resizeHandleUnderCursor);
  }
}
