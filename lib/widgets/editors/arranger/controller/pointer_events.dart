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

part of 'arranger_controller.dart';

/// These are the possible states that the arranger can have during event
/// handing. The current state tells the controller how to handle incoming
/// pointer events.
enum EventHandlingState {
  /// Nothing is happening.
  idle,

  /// A single clip is being moved.
  movingSingleClip,

  /// A selection of clips are being moved.
  movingSelection,

  /// An additive selection box is being drawn. Clips under this box will be
  /// added to the current selection.
  creatingAdditiveSelectionBox,

  /// A subtractive selection box is being drawn. Clips under this box will be
  /// removed from the current selection if they are selected.
  creatingSubtractiveSelectionBox,
}

mixin _ArrangerPointerEventsMixin on _ArrangerController {
  var _eventHandlingState = EventHandlingState.idle;

  // Data for selection box
  Point<double>? _selectionBoxStart;
  Set<ID>? _selectionBoxOriginalSelection;

  void pointerDown(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    if (event.pointerEvent.buttons & kPrimaryMouseButton ==
        kPrimaryMouseButton) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryMouseButton ==
        kSecondaryMouseButton) {
      rightPointerDown(event);
    }
  }

  void leftPointerDown(ArrangerPointerEvent event) {
    final arrangement =
        project.song.arrangements[project.song.activeArrangementID]!;

    if (event.keyboardModifiers.ctrl) {
      if (event.keyboardModifiers.shift &&
          event.clipUnderCursor != null &&
          viewModel.selectedClips.nonObservableInner
              .contains(event.clipUnderCursor)) {
        _eventHandlingState =
            EventHandlingState.creatingSubtractiveSelectionBox;
      } else {
        _eventHandlingState = EventHandlingState.creatingAdditiveSelectionBox;
      }

      if (!event.keyboardModifiers.shift) {
        viewModel.selectedClips.clear();
      }

      _selectionBoxStart = Point(event.offset, event.track);
      _selectionBoxOriginalSelection =
          viewModel.selectedClips.nonObservableInner;
      return;
    }

    // void setMoveClipInfo(ClipModel clipUnderCursor) {

    // }

    // If there's no active cursor pattern, we don't want to add any clips
    if (viewModel.cursorPattern == null) return;

    final eventTime = event.offset.floor();
    if (eventTime < 0) return;

    final divisionChanges = getDivisionChanges(
      viewWidthInPixels: event.arrangerSize.width,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      defaultTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: [],
      ticksPerQuarter: project.song.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );

    final targetTime = event.keyboardModifiers.alt
        ? eventTime
        : getSnappedTime(
            rawTime: eventTime,
            divisionChanges: divisionChanges,
          );

    project.startJournalPage();

    project.execute(
      AddClipCommand(
        project: project,
        arrangementID: arrangement.id,
        trackID: project.song.trackOrder[event.track.floor()],
        patternID: viewModel.cursorPattern!,
        offset: targetTime,
      ),
    );
  }

  void rightPointerDown(ArrangerPointerEvent event) {}

  void pointerMove(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    switch (_eventHandlingState) {
      case EventHandlingState.idle:
        return;
      case EventHandlingState.movingSingleClip:
      case EventHandlingState.movingSelection:
        break;
      case EventHandlingState.creatingAdditiveSelectionBox:
      case EventHandlingState.creatingSubtractiveSelectionBox:
        final arrangement =
            project.song.arrangements[project.song.activeArrangementID];
        if (arrangement == null) return;

        final isSubtractive = _eventHandlingState ==
            EventHandlingState.creatingSubtractiveSelectionBox;

        viewModel.selectionBox = Rectangle.fromPoints(
          _selectionBoxStart!,
          Point(event.offset, event.track),
        );

        final clipsInSelection = arrangement.clips.values
            .where(
              (clip) {
                final trackTop =
                    project.song.trackOrder.indexOf(clip.trackID).toDouble();

                return viewModel.selectionBox!.intersects(
                  Rectangle(
                    clip.offset,
                    trackTop,
                    clip.width,
                    1,
                  ),
                );
              },
            )
            .map((clip) => clip.clipID)
            .toSet();

        if (isSubtractive) {
          viewModel.selectedClips = ObservableSet.of(
            _selectionBoxOriginalSelection!.difference(clipsInSelection),
          );
        } else {
          viewModel.selectedClips = ObservableSet.of(
            _selectionBoxOriginalSelection!.union(clipsInSelection),
          );
        }

        break;
    }
  }

  void pointerUp(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    viewModel.selectionBox = null;

    project.commitJournalPage();

    _selectionBoxStart = null;
  }
}
