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

  /// A single clip is being resized.
  resizingSingleClip,

  /// A selection of clips are being resized.
  resizingSelection,
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

  // Data for clip resize
  double? _clipResizePointerStartOffset;
  Map<ID, Time>? _clipResizeStartWidths;
  Map<ID, Time>? _clipResizeStartTimeViewStarts;
  Map<ID, Time>? _clipResizeStartOffsets;
  TimeRange? _clipResizeSmallestStartTimeRange;
  ID? _clipResizeSmallestClip;
  ClipModel? _clipResizePressedClip;
  bool? _clipResizeIsFromStartOfClip;

  void pointerDown(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    if (event.pointerEvent.buttons & kPrimaryMouseButton ==
            kPrimaryMouseButton &&
        viewModel.tool != EditorTool.eraser) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryMouseButton ==
            kSecondaryMouseButton ||
        viewModel.tool == EditorTool.eraser) {
      rightPointerDown(event);
    }
  }

  void leftPointerDown(ArrangerPointerEvent event) {
    final arrangement =
        project.song.arrangements[project.song.activeArrangementID]!;

    if (event.keyboardModifiers.ctrl || viewModel.tool == EditorTool.select) {
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

    if (event.isResizeFromStart || event.isResizeFromEnd) {
      if (event.clipUnderCursor == null) {
        throw ArgumentError("Resize event didn't provide clipUnderCursor");
      }

      final pressedClip = arrangement.clips[event.clipUnderCursor]!;

      viewModel.pressedClip = pressedClip.id;

      _clipResizePointerStartOffset = event.offset;
      _clipResizePressedClip = pressedClip;

      // If we somehow get both as true, we only want to call it a start resize
      // if it's not an end resize.
      _clipResizeIsFromStartOfClip = !event.isResizeFromEnd;

      if (viewModel.selectedClips.contains(pressedClip.id)) {
        _eventHandlingState = EventHandlingState.resizingSelection;

        final selectedClips =
            viewModel.selectedClips.map((id) => arrangement.clips[id]!);

        var smallestClip = selectedClips.first;
        var smallestClipWidth = smallestClip.getWidth(project);
        _clipResizeStartWidths = {};
        _clipResizeStartOffsets = {};
        _clipResizeStartTimeViewStarts = {};

        for (final clip in selectedClips) {
          final clipWidth = clip.getWidth(project);

          _clipResizeStartWidths![clip.id] = clipWidth;
          _clipResizeStartOffsets![clip.id] = clip.offset;
          _clipResizeStartTimeViewStarts![clip.id] = clip.timeView?.start ?? 0;

          if (clipWidth < smallestClipWidth) {
            smallestClip = clip;
            smallestClipWidth = clipWidth;
          }
        }

        _clipResizeSmallestStartTimeRange = TimeRange(
          smallestClip.timeView?.start.toDouble() ?? 0,
          smallestClip.timeView?.end.toDouble() ?? smallestClipWidth.toDouble(),
        );
        _clipResizeSmallestClip = smallestClip.id;
      } else {
        _eventHandlingState = EventHandlingState.resizingSingleClip;
        viewModel.selectedClips.clear();

        final clipWidth = pressedClip.getWidth(project);

        _clipResizeStartWidths = {pressedClip.id: clipWidth};
        _clipResizeStartOffsets = {pressedClip.id: pressedClip.offset};
        _clipResizeStartTimeViewStarts = {
          pressedClip.id: pressedClip.timeView?.start ?? 0
        };
        _clipResizeSmallestStartTimeRange = TimeRange(
          pressedClip.timeView?.start.toDouble() ?? 0,
          pressedClip.timeView?.end.toDouble() ?? clipWidth.toDouble(),
        );
        _clipResizeSmallestClip = pressedClip.id;
      }

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
      viewModel.pressedClip = pressedClip.id;

      if (viewModel.selectedClips.contains(pressedClip.id)) {
        _eventHandlingState = EventHandlingState.movingSelection;

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

          final newSelectedNotes = ObservableSet<String>();

          for (final clip
              in viewModel.selectedClips.map((id) => arrangement.clips[id]!)) {
            final newClip = ClipModel.fromClipModel(clip);

            if (viewModel.pressedClip == clip.id) {
              viewModel.pressedClip = newClip.id;
            }

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
        viewModel.cursorPattern = pressedClip.patternID;
        viewModel.cursorTimeRange = pressedClip.timeView?.clone();

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

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
      snap: AutoSnap(),
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

    final clip = ClipModel.create(
      trackID: project.song.trackOrder[event.track.floor()],
      patternID: viewModel.cursorPattern!,
      offset: targetTime,
      timeView: viewModel.cursorTimeRange?.clone(),
    );

    final command = AddClipCommand(
      project: project,
      arrangementID: arrangement.id,
      clip: clip,
    );

    viewModel.pressedClip = clip.id;

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
            clip.offset + clip.getWidth(project) > event.offset;

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
          snap: AutoSnap(),
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
                  Rectangle(clip.offset, trackTop, clip.getWidth(project), 1),
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
              Point(clip.offset + clip.getWidth(project), clipTrack + 1);

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
      case EventHandlingState.resizingSingleClip:
      case EventHandlingState.resizingSelection:
        final arrangement =
            project.song.arrangements[project.song.activeArrangementID]!;

        var snappedOriginalTime = _clipResizePointerStartOffset!.floor();
        var snappedEventTime = event.offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.arrangerSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: [],
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOriginalTime = getSnappedTime(
            rawTime: _clipResizePointerStartOffset!.floor(),
            divisionChanges: divisionChanges,
            round: true,
          );

          snappedEventTime = getSnappedTime(
            rawTime: event.offset.floor(),
            divisionChanges: divisionChanges,
            round: true,
          );
        }

        late int snapAtSmallestClipStart;

        final offsetOfSmallestClipAtStart =
            _clipResizeStartWidths![_clipResizeSmallestClip]!;

        for (var i = 0; i < divisionChanges.length; i++) {
          if (i < divisionChanges.length - 1 &&
              divisionChanges[i + 1].offset <= offsetOfSmallestClipAtStart) {
            continue;
          }

          snapAtSmallestClipStart = divisionChanges[i].divisionSnapSize;

          break;
        }

        var diff = snappedEventTime - snappedOriginalTime;

        if (_clipResizeIsFromStartOfClip!) {
          diff = -diff; // Means we don't need to modify the calculation below.
        }

        // Make sure no clips go below the smallest snap size if snapping is
        // enabled.
        if (!event.keyboardModifiers.alt &&
            _clipResizeSmallestStartTimeRange!.width + diff <
                snapAtSmallestClipStart) {
          int snapCount = ((snapAtSmallestClipStart -
                      (_clipResizeSmallestStartTimeRange!.width + diff)) /
                  snapAtSmallestClipStart)
              .ceil();
          diff = diff + snapCount * snapAtSmallestClipStart;
        }

        // If snapping is disabled, make sure the clips all have a length of at
        // least 1.
        if (event.keyboardModifiers.alt) {
          final newSmallestClipSize =
              (_clipResizeSmallestStartTimeRange!.width + diff).round();
          if (newSmallestClipSize < 1) {
            diff += 1 - newSmallestClipSize;
          }
        }

        if (_clipResizeIsFromStartOfClip!) {
          diff = -diff; // Means we don't need to modify the calculation above.
        }

        for (final clip in arrangement.clips.values
            .where((clip) => _clipResizeStartWidths!.containsKey(clip.id))) {
          if (clip.timeView == null) {
            final width = _clipResizeStartWidths![clip.id]!;
            clip.timeView = TimeViewModel(start: 0, end: width);
          }

          if (_clipResizeIsFromStartOfClip!) {
            clip.timeView!.start =
                _clipResizeStartTimeViewStarts![clip.id]! + diff;
            clip.offset = _clipResizeStartOffsets![clip.id]! + diff;
          } else {
            clip.timeView!.end =
                clip.timeView!.start + _clipResizeStartWidths![clip.id]! + diff;
          }
        }

        if (_eventHandlingState == EventHandlingState.resizingSingleClip) {
          // Update cursor pattern and time range
          viewModel.cursorPattern = _clipResizePressedClip!.patternID;
          viewModel.cursorTimeRange = _clipResizePressedClip!.timeView?.clone();
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
    } else if (_eventHandlingState == EventHandlingState.resizingSingleClip ||
        _eventHandlingState == EventHandlingState.resizingSelection) {
      final arrangement =
          project.song.arrangements[project.song.activeArrangementID]!;

      final commands = _clipResizeStartWidths!.keys.map((id) {
        final clip = arrangement.clips[id]!;
        final oldStart = _clipResizeStartTimeViewStarts![id]!;
        final oldWidth = _clipResizeStartWidths![id]!;

        return ResizeClipCommand(
          project: project,
          arrangementID: project.song.activeArrangementID!,
          clipID: id,
          oldOffset: _clipResizeStartOffsets![id]!,
          oldTimeView: TimeViewModel(
            start: oldStart,
            end: oldStart + oldWidth,
          ),
          newOffset: clip.offset,
          newTimeView: clip.timeView?.clone() ??
              TimeViewModel(
                start: 0,
                end: clip.getWidth(project),
              ),
        );
      }).toList();

      final command = JournalPageCommand(project, commands);

      project.push(command);
    }

    _eventHandlingState = EventHandlingState.idle;

    viewModel.selectionBox = null;
    viewModel.pressedClip = null;

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

    _clipResizePointerStartOffset = null;
    _clipResizeStartWidths = null;
    _clipResizeStartOffsets = null;
    _clipResizeStartTimeViewStarts = null;
    _clipResizeSmallestStartTimeRange = null;
    _clipResizeSmallestClip = null;
    _clipResizePressedClip = null;
    _clipResizeIsFromStartOfClip = null;
  }
}
