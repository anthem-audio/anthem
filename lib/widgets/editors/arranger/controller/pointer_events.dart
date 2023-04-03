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

  // Data for clip moves
  ClipModel? _clipMoveClipUnderCusror;
  double? _clipMoveTimeOffset;
  double? _clipMoveTrackOffset;
  Map<ID, Time>? _clipMoveStartTimes;
  Map<ID, int>? _clipMoveStartTracks;
  Time? _clipMoveStartOfFirstClip;
  int? _clipMoveTrackOfTopClip;
  int? _clipMoveTrackOfBottomClip;

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

    void setMoveClipInfo(ClipModel clipUnderCursor) {
      _clipMoveClipUnderCusror = clipUnderCursor;
      _clipMoveTimeOffset = event.offset - clipUnderCursor.offset;
      _clipMoveTrackOffset = 0.5;
      _clipMoveStartTimes = {clipUnderCursor.id: clipUnderCursor.offset};
      _clipMoveStartTracks = {
        clipUnderCursor.id:
            project.song.trackOrder.indexOf(clipUnderCursor.trackID)
      };

      if (_eventHandlingState == EventHandlingState.movingSelection) {
      } else {
        _clipMoveStartOfFirstClip = clipUnderCursor.offset;
        _clipMoveTrackOfTopClip = _clipMoveStartTracks![clipUnderCursor.id]!;
        _clipMoveTrackOfBottomClip = _clipMoveStartTracks![clipUnderCursor.id]!;
      }
    }

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

    final command = AddClipCommand(
      project: project,
      arrangementID: arrangement.id,
      trackID: project.song.trackOrder[event.track.floor()],
      patternID: viewModel.cursorPattern!,
      offset: targetTime,
    );

    project.execute(command);

    _eventHandlingState = EventHandlingState.movingSingleClip;

    setMoveClipInfo(arrangement.clips[command.clipID]!);
  }

  void rightPointerDown(ArrangerPointerEvent event) {}

  void pointerMove(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    switch (_eventHandlingState) {
      case EventHandlingState.idle:
        return;
      case EventHandlingState.movingSingleClip:
      case EventHandlingState.movingSelection:
        final isSelectionMove =
            _eventHandlingState == EventHandlingState.movingSelection;

        final track = event.track - _clipMoveTrackOffset!;
        final offset = event.offset - _clipMoveTimeOffset!;

        final arrangement =
            project.song.arrangements[project.song.activeArrangementID]!;
        final clips = isSelectionMove
            ? viewModel.selectedClips
                .map((clipID) => arrangement.clips[clipID]!)
            : [_clipMoveClipUnderCusror!];

        var snappedOffset = offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.arrangerSize.width,
          snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: [],
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOffset = getSnappedTime(
            rawTime: offset.floor(),
            divisionChanges: divisionChanges,
            round: true,
            startTime: _clipMoveStartTimes![_clipMoveClipUnderCusror!.id]!,
          );
        }

        var timeOffsetFromEventStart =
            snappedOffset - _clipMoveStartTimes![_clipMoveClipUnderCusror!.id]!;
        var trackOffsetFromEventStart = track.round() -
            _clipMoveStartTracks![_clipMoveClipUnderCusror!.id]!;

        // Prevent the leftmost track from going earlier than the start of the arrangement
        if (_clipMoveStartOfFirstClip! + timeOffsetFromEventStart < 0) {
          timeOffsetFromEventStart = -_clipMoveStartOfFirstClip!;
        }

        // Prevent the top key from going above the highest allowed note
        if (_clipMoveTrackOfTopClip! + trackOffsetFromEventStart < 0) {
          trackOffsetFromEventStart = -_clipMoveTrackOfTopClip!;
        }

        // Prevent the bottom key from going below the lowest allowed note
        if (_clipMoveTrackOfBottomClip! + trackOffsetFromEventStart >=
            project.song.trackOrder.length) {
          trackOffsetFromEventStart =
              project.song.trackOrder.length - 1 - _clipMoveTrackOfBottomClip!;
        }

        for (final clip in clips) {
          final shift = event.keyboardModifiers.shift;
          final ctrl = event.keyboardModifiers.ctrl;

          final track = _clipMoveStartTracks![clip.id]! +
              (shift ? 0 : trackOffsetFromEventStart);
          clip.trackID = project.song.trackOrder[track];

          clip.offset = _clipMoveStartTimes![clip.id]! +
              (!shift && ctrl ? 0 : timeOffsetFromEventStart);
        }

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
                  Rectangle(clip.offset, trackTop, clip.width, 1),
                );
              },
            )
            .map((clip) => clip.id)
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

    if (_eventHandlingState == EventHandlingState.movingSingleClip ||
        _eventHandlingState == EventHandlingState.movingSelection) {
      final arrangement =
          project.song.arrangements[project.song.activeArrangementID]!;
      final clips = arrangement.clips;

      final isSingleClip =
          _eventHandlingState == EventHandlingState.movingSingleClip;

      final relevantClips = isSingleClip
          ? [_clipMoveClipUnderCusror!]
          : viewModel.selectedClips.map((clipID) => clips[clipID]!).toList();

      final commands = relevantClips.map((clip) {
        return MoveClipCommand(
          project: project,
          arrangementID: arrangement.id,
          clipID: clip.id,
          oldOffset: _clipMoveStartTimes![clip.id]!,
          newOffset: clip.offset,
          oldTrack: project.song.trackOrder[_clipMoveStartTracks![clip.id]!],
          newTrack: clip.trackID,
        );
      }).toList();

      project.push(JournalPageCommand(project, commands));
    }

    viewModel.selectionBox = null;

    project.commitJournalPage();

    _clipMoveClipUnderCusror = null;
    _clipMoveTimeOffset = null;
    _clipMoveTrackOffset = null;
    _clipMoveStartTimes = null;
    _clipMoveStartTracks = null;
    _clipMoveStartOfFirstClip = null;
    _clipMoveTrackOfTopClip = null;
    _clipMoveTrackOfBottomClip = null;

    _selectionBoxStart = null;
    _selectionBoxOriginalSelection = null;
  }
}
