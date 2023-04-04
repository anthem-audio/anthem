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

  /// Notes under the cursor are being deleted.
  deleting,
}

mixin _ArrangerPointerEventsMixin on _ArrangerController {
  var _eventHandlingState = EventHandlingState.idle;

  // Data for clip moves
  ClipModel? _clipMoveClipUnderCursor;
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

  // Data for deleting clips

  /// We ignore clips under the cursor, except the topmost one, until the user
  /// moves the mouse off the note and back on. This means that the user
  /// doesn't right click to delete an overlapping note, accidentally move the
  /// mouse by one pixel, and delete additional clips.
  Set<ClipModel>? _deleteClipsToTemporarilyIgnore;
  Set<ClipModel>? _deleteClipsDeleted;
  Point? _deleteMostRecentPoint;

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

    // If there's no active cursor pattern, we don't want to add any clips
    if (viewModel.cursorPattern == null) return;

    void setMoveClipInfo(ClipModel clipUnderCursor) {
      _clipMoveClipUnderCursor = clipUnderCursor;
      _clipMoveTimeOffset = event.offset - clipUnderCursor.offset;
      _clipMoveTrackOffset = 0.5;
      _clipMoveStartTimes = {clipUnderCursor.id: clipUnderCursor.offset};
      _clipMoveStartTracks = {
        clipUnderCursor.id:
            project.song.trackOrder.indexOf(clipUnderCursor.trackID)
      };

      // If we're moving a selection, record the start times
      for (final clip in viewModel.selectedClips
          .map((clipID) => arrangement.clips[clipID]!)) {
        _clipMoveStartTimes![clip.id] = clip.offset;
        _clipMoveStartTracks![clip.id] =
            project.song.trackOrder.indexOf(clip.trackID);
      }

      if (_eventHandlingState == EventHandlingState.movingSelection) {
        _clipMoveStartOfFirstClip = viewModel.selectedClips.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, clipID) =>
              min(previousValue, arrangement.clips[clipID]!.offset),
        );

        _clipMoveTrackOfTopClip = 0x7FFFFFFFFFFFFFFF;
        _clipMoveTrackOfBottomClip = 0;

        // This has a worst-case complexity of clipCount * trackCount
        for (final clipID in viewModel.selectedClips) {
          final clipIndex = project.song.trackOrder
              .indexOf(arrangement.clips[clipID]!.trackID);
          _clipMoveTrackOfTopClip = min(_clipMoveTrackOfTopClip!, clipIndex);
          _clipMoveTrackOfBottomClip =
              max(_clipMoveTrackOfBottomClip!, clipIndex);
        }
      } else {
        _clipMoveStartOfFirstClip = clipUnderCursor.offset;
        _clipMoveTrackOfTopClip = _clipMoveStartTracks![clipUnderCursor.id]!;
        _clipMoveTrackOfBottomClip = _clipMoveStartTracks![clipUnderCursor.id]!;
      }
    }

    if (event.clipUnderCursor != null) {
      final pressedClip = arrangement.clips[event.clipUnderCursor]!;

      if (viewModel.selectedClips.contains(pressedClip.id)) {
        _eventHandlingState = EventHandlingState.movingSelection;

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

          final newSelectedNotes = ObservableSet<String>();

          for (final clip
              in viewModel.selectedClips.map((id) => arrangement.clips[id]!)) {
            final newClip = ClipModel.fromClipModel(clip);

            project.execute(AddClipCommand(
              project: project,
              arrangementID: arrangement.id,
              clip: newClip,
            ));

            newSelectedNotes.add(newClip.id);
          }

          viewModel.selectedClips = newSelectedNotes;
        }
      } else {
        _eventHandlingState = EventHandlingState.movingSingleClip;
        viewModel.selectedClips.clear();

        if (event.keyboardModifiers.shift) {
          final newClip = ClipModel.fromClipModel(pressedClip);

          project.execute(AddClipCommand(
            project: project,
            arrangementID: arrangement.id,
            clip: newClip,
          ));
        }
      }

      setMoveClipInfo(pressedClip);

      return;
    }

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
      clip: ClipModel.create(
        project: project,
        trackID: project.song.trackOrder[event.track.floor()],
        patternID: viewModel.cursorPattern!,
        offset: targetTime,
      ),
    );

    project.execute(command);

    _eventHandlingState = EventHandlingState.movingSingleClip;
    viewModel.selectedClips.clear();

    setMoveClipInfo(arrangement.clips[command.clip.id]!);
  }

  void rightPointerDown(ArrangerPointerEvent event) {
    _eventHandlingState = EventHandlingState.deleting;

    _deleteMostRecentPoint = Point(event.offset, event.track);

    project.startJournalPage();

    final arrangement =
        project.song.arrangements[project.song.activeArrangementID]!;

    _deleteClipsDeleted = {};
    _deleteClipsToTemporarilyIgnore = {};

    if (event.clipUnderCursor != null) {
      arrangement.clips.removeWhere((clipID, clip) {
        final remove = clip.id == event.clipUnderCursor &&
            // Ignore events that come from the resize handle but aren't over
            // the clip.
            clip.offset + clip.width > event.offset;

        if (remove) {
          _deleteClipsDeleted!.add(clip);
          viewModel.selectedClips.remove(clip.id);
        }
        return remove;
      });
    }
  }

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
            : [_clipMoveClipUnderCursor!];

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
            startTime: _clipMoveStartTimes![_clipMoveClipUnderCursor!.id]!,
          );
        }

        var timeOffsetFromEventStart =
            snappedOffset - _clipMoveStartTimes![_clipMoveClipUnderCursor!.id]!;
        var trackOffsetFromEventStart = track.round() -
            _clipMoveStartTracks![_clipMoveClipUnderCursor!.id]!;

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
      case EventHandlingState.deleting:
        final arrangement =
            project.song.arrangements[project.song.activeArrangementID]!;

        final thisPoint = Point(event.offset, event.track);

        final clipsUnderCursorPath = arrangement.clips.values.where((clip) {
          // This might be too inefficient... For each clip, we have to get the
          // index of its track in the track list. This is fine if there's not
          // a lot of clips or not a lot of tracks, or if the clips are all
          // near the top (this last one is pretty likely), but feels not-so-
          // great to me for larger projects. I don't want to prematurely
          // optimize though, so I'm leaving this note for the next weary
          // traveler.
          final clipTrack = project.song.trackOrder.indexOf(clip.trackID);

          final clipTopLeft = Point(clip.offset, clipTrack);
          final clipBottomRight =
              Point(clip.offset + clip.width, clipTrack + 1);

          return rectanglesIntersect(
                Rectangle.fromPoints(
                  _deleteMostRecentPoint!,
                  thisPoint,
                ),
                Rectangle.fromPoints(
                  clipTopLeft,
                  clipBottomRight,
                ),
              ) &&
              lineIntersectsBox(
                _deleteMostRecentPoint!,
                thisPoint,
                clipTopLeft,
                clipBottomRight,
              );
        }).toList();

        final clipsToRemoveFromIgnore = <ClipModel>[];

        for (final clip in _deleteClipsToTemporarilyIgnore!) {
          if (!clipsUnderCursorPath.contains(clip)) {
            clipsToRemoveFromIgnore.add(clip);
          }
        }

        for (final clip in clipsToRemoveFromIgnore) {
          _deleteClipsToTemporarilyIgnore!.remove(clip);
        }

        for (final clip in clipsUnderCursorPath) {
          if (_deleteClipsToTemporarilyIgnore!.contains(clip)) {
            continue;
          }

          arrangement.clips.remove(clip.id);
          _deleteClipsDeleted!.add(clip);
          viewModel.selectedClips.remove(clip.id);
        }

        _deleteMostRecentPoint = thisPoint;

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
          ? [_clipMoveClipUnderCursor!]
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
    } else if (_eventHandlingState == EventHandlingState.deleting) {
      // There should already be an active journal page, so we don't need to
      // collect these manually.
      for (final clip in _deleteClipsDeleted!) {
        final command = DeleteClipCommand(
          project: project,
          arrangementID: project.song.activeArrangementID!,
          clip: clip,
        );

        project.push(command);
      }
    }

    _eventHandlingState = EventHandlingState.idle;

    viewModel.selectionBox = null;

    project.commitJournalPage();

    _clipMoveClipUnderCursor = null;
    _clipMoveTimeOffset = null;
    _clipMoveTrackOffset = null;
    _clipMoveStartTimes = null;
    _clipMoveStartTracks = null;
    _clipMoveStartOfFirstClip = null;
    _clipMoveTrackOfTopClip = null;
    _clipMoveTrackOfBottomClip = null;

    _selectionBoxStart = null;
    _selectionBoxOriginalSelection = null;

    _deleteClipsToTemporarilyIgnore = null;
    _deleteClipsDeleted = null;
    _deleteMostRecentPoint = null;
  }
}
