/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;

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

class _ClipMoveActionData {
  ClipModel clipUnderCursor;
  double timeOffset;
  double trackOffset;
  Map<Id, Time> startTimes;
  Map<Id, int> startTracks;
  Time startOfFirstClip;
  int trackOfTopClip;
  int trackOfBottomClip;

  _ClipMoveActionData({
    required this.clipUnderCursor,
    required this.timeOffset,
    required this.trackOffset,
    required this.startTimes,
    required this.startTracks,
    required this.startOfFirstClip,
    required this.trackOfTopClip,
    required this.trackOfBottomClip,
  });
}

class _SelectionBoxActionData {
  Point<double> start;
  Set<Id> originalSelection;

  _SelectionBoxActionData({
    required this.start,
    required this.originalSelection,
  });
}

class _DeleteActionData {
  /// We ignore clips under the cursor, except the topmost one, until the user
  /// moves the mouse off the note and back on. This means that the user
  /// doesn't right click to delete an overlapping note, accidentally move the
  /// mouse by one pixel, and delete additional clips.
  Set<ClipModel> clipsToTemporarilyIgnore;
  Set<ClipModel> clipsDeleted;
  Point mostRecentPoint;

  _DeleteActionData({
    required this.clipsToTemporarilyIgnore,
    required this.clipsDeleted,
    required this.mostRecentPoint,
  });
}

class _ClipResizeActionData {
  double pointerStartOffset;
  Map<Id, Time> startWidths;
  Map<Id, Time> startTimeViewStarts;
  Map<Id, Time> startOffsets;
  TimeRange smallestStartTimeRange;
  Id smallestClip;
  ClipModel pressedClip;
  bool isFromStartOfClip;

  _ClipResizeActionData({
    required this.pointerStartOffset,
    required this.startWidths,
    required this.startTimeViewStarts,
    required this.startOffsets,
    required this.smallestStartTimeRange,
    required this.smallestClip,
    required this.pressedClip,
    required this.isFromStartOfClip,
  });
}

mixin _ArrangerPointerEventsMixin on _ArrangerController {
  var _eventHandlingState = EventHandlingState.idle;

  // Data for clip moves
  _ClipMoveActionData? _clipMoveActionData;

  // Data for selection box
  _SelectionBoxActionData? _selectionBoxActionData;

  // Data for deleting clips
  _DeleteActionData? _deleteActionData;

  // Data for clip resize
  _ClipResizeActionData? _clipResizeActionData;

  void pointerDown(ArrangerPointerEvent event) {
    if (project.sequence.activeArrangementID == null) return;

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
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    if (event.keyboardModifiers.ctrl || viewModel.tool == EditorTool.select) {
      if (event.keyboardModifiers.shift &&
          event.clipUnderCursor != null &&
          viewModel.selectedClips.nonObservableInner.contains(
            event.clipUnderCursor,
          )) {
        _eventHandlingState =
            EventHandlingState.creatingSubtractiveSelectionBox;
      } else {
        _eventHandlingState = EventHandlingState.creatingAdditiveSelectionBox;
      }

      if (!event.keyboardModifiers.shift) {
        viewModel.selectedClips.clear();
      }

      _selectionBoxActionData = _SelectionBoxActionData(
        start: Point(event.offset, event.track),
        originalSelection: viewModel.selectedClips.nonObservableInner,
      );

      return;
    }

    if (event.isResizeFromStart || event.isResizeFromEnd) {
      if (event.clipUnderCursor == null) {
        throw ArgumentError("Resize event didn't provide clipUnderCursor");
      }

      final pressedClip = arrangement.clips[event.clipUnderCursor]!;

      viewModel.pressedClip = pressedClip.id;

      late Map<String, int> startWidths;
      late Map<String, int> startOffsets;
      late Map<String, int> startTimeViewStarts;
      late TimeRange smallestStartTimeRange;
      late String smallestClipId;

      if (viewModel.selectedClips.contains(pressedClip.id)) {
        _eventHandlingState = EventHandlingState.resizingSelection;

        final selectedClips = viewModel.selectedClips.map(
          (id) => arrangement.clips[id]!,
        );

        var smallestClip = selectedClips.first;
        var smallestClipWidth = smallestClip.width;
        startWidths = {};
        startOffsets = {};
        startTimeViewStarts = {};

        for (final clip in selectedClips) {
          final clipWidth = clip.width;

          startWidths[clip.id] = clipWidth;
          startOffsets[clip.id] = clip.offset;
          startTimeViewStarts[clip.id] = clip.timeView?.start ?? 0;

          if (clipWidth < smallestClipWidth) {
            smallestClip = clip;
            smallestClipWidth = clipWidth;
          }
        }

        smallestStartTimeRange = TimeRange(
          smallestClip.timeView?.start.toDouble() ?? 0,
          smallestClip.timeView?.end.toDouble() ?? smallestClipWidth.toDouble(),
        );
        smallestClipId = smallestClip.id;
      } else {
        _eventHandlingState = EventHandlingState.resizingSingleClip;
        viewModel.selectedClips.clear();

        final clipWidth = pressedClip.width;

        startWidths = {pressedClip.id: clipWidth};
        startOffsets = {pressedClip.id: pressedClip.offset};
        startTimeViewStarts = {
          pressedClip.id: pressedClip.timeView?.start ?? 0,
        };
        smallestStartTimeRange = TimeRange(
          pressedClip.timeView?.start.toDouble() ?? 0,
          pressedClip.timeView?.end.toDouble() ?? clipWidth.toDouble(),
        );
        smallestClipId = pressedClip.id;
      }

      viewModel.cursorPattern = pressedClip.patternId;
      viewModel.cursorTimeRange = pressedClip.timeView?.clone();

      _clipResizeActionData = _ClipResizeActionData(
        pointerStartOffset: event.offset,
        pressedClip: pressedClip,

        // If we somehow get both as true, we only want to call it a start resize
        // if it's not an end resize.
        isFromStartOfClip: !event.isResizeFromEnd,

        startWidths: startWidths,
        startOffsets: startOffsets,
        startTimeViewStarts: startTimeViewStarts,
        smallestStartTimeRange: smallestStartTimeRange,
        smallestClip: smallestClipId,
      );

      return;
    }

    // If there's no active cursor pattern, we don't want to add any clips
    if (viewModel.cursorPattern == null) return;

    void setMoveClipInfo(ClipModel clipUnderCursor) {
      _clipMoveActionData = _ClipMoveActionData(
        clipUnderCursor: clipUnderCursor,
        timeOffset: event.offset - clipUnderCursor.offset,
        trackOffset: 0.5,
        startTimes: {clipUnderCursor.id: clipUnderCursor.offset},
        startTracks: {
          clipUnderCursor.id: project.trackOrder.indexOf(
            clipUnderCursor.trackId,
          ),
        },
        startOfFirstClip: -1,
        trackOfTopClip: -1,
        trackOfBottomClip: -1,
      );

      // If we're moving a selection, record the start times
      for (final clip in viewModel.selectedClips.map(
        (clipID) => arrangement.clips[clipID]!,
      )) {
        _clipMoveActionData!.startTimes[clip.id] = clip.offset;
        _clipMoveActionData!.startTracks[clip.id] = project.trackOrder.indexOf(
          clip.trackId,
        );
      }

      if (_eventHandlingState == EventHandlingState.movingSelection) {
        _clipMoveActionData!.startOfFirstClip = viewModel.selectedClips
            .fold<int>(
              maxSafeIntWeb,
              (previousValue, clipID) =>
                  min(previousValue, arrangement.clips[clipID]!.offset),
            );

        _clipMoveActionData!.trackOfTopClip = maxSafeIntWeb;
        _clipMoveActionData!.trackOfBottomClip = 0;

        // This has a worst-case complexity of clipCount * trackCount
        for (final clipID in viewModel.selectedClips) {
          final clipIndex = project.trackOrder.indexOf(
            arrangement.clips[clipID]!.trackId,
          );
          _clipMoveActionData!.trackOfTopClip = min(
            _clipMoveActionData!.trackOfTopClip,
            clipIndex,
          );
          _clipMoveActionData!.trackOfBottomClip = max(
            _clipMoveActionData!.trackOfBottomClip,
            clipIndex,
          );
        }
      } else {
        _clipMoveActionData!.startOfFirstClip = clipUnderCursor.offset;
        _clipMoveActionData!.trackOfTopClip =
            _clipMoveActionData!.startTracks[clipUnderCursor.id]!;
        _clipMoveActionData!.trackOfBottomClip =
            _clipMoveActionData!.startTracks[clipUnderCursor.id]!;
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

          for (final clip in viewModel.selectedClips.map(
            (id) => arrangement.clips[id]!,
          )) {
            final newClip = ClipModel.fromClipModel(clip);

            if (viewModel.pressedClip == clip.id) {
              viewModel.pressedClip = newClip.id;
            }

            project.execute(
              AddClipCommand(arrangementID: arrangement.id, clip: newClip),
            );

            newSelectedNotes.add(newClip.id);
          }

          viewModel.selectedClips = newSelectedNotes;
        }
      } else {
        _eventHandlingState = EventHandlingState.movingSingleClip;
        viewModel.selectedClips.clear();
        viewModel.cursorPattern = pressedClip.patternId;
        viewModel.cursorTimeRange = pressedClip.timeView?.clone();

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

          final newClip = ClipModel.fromClipModel(pressedClip);

          project.execute(
            AddClipCommand(arrangementID: arrangement.id, clip: newClip),
          );
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
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: [],
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );

    final targetTime = event.keyboardModifiers.alt
        ? eventTime
        : getSnappedTime(rawTime: eventTime, divisionChanges: divisionChanges);

    project.startJournalPage();

    final clip = ClipModel.create(
      trackId: project.trackOrder[event.track.floor()],
      patternId: viewModel.cursorPattern!,
      offset: targetTime,
      timeView: viewModel.cursorTimeRange?.clone(),
    );

    final command = AddClipCommand(arrangementID: arrangement.id, clip: clip);

    viewModel.pressedClip = clip.id;

    project.execute(command);

    _eventHandlingState = EventHandlingState.movingSingleClip;
    viewModel.selectedClips.clear();

    setMoveClipInfo(arrangement.clips[command.clip.id]!);
  }

  void rightPointerDown(ArrangerPointerEvent event) {
    _eventHandlingState = EventHandlingState.deleting;

    project.startJournalPage();

    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    _deleteActionData = _DeleteActionData(
      mostRecentPoint: Point(event.offset, event.track),
      clipsToTemporarilyIgnore: {},
      clipsDeleted: {},
    );

    if (event.clipUnderCursor != null) {
      arrangement.clips.removeWhere((clipID, clip) {
        final remove =
            clip.id == event.clipUnderCursor &&
            // Ignore events that come from the resize handle but aren't over
            // the clip.
            clip.offset + clip.width > event.offset;

        if (remove) {
          _deleteActionData!.clipsDeleted.add(clip);
          viewModel.selectedClips.remove(clip.id);
        }
        return remove;
      });
    }
  }

  void pointerMove(ArrangerPointerEvent event) {
    if (project.sequence.activeArrangementID == null) return;

    switch (_eventHandlingState) {
      case EventHandlingState.idle:
        return;
      case EventHandlingState.movingSingleClip:
      case EventHandlingState.movingSelection:
        final isSelectionMove =
            _eventHandlingState == EventHandlingState.movingSelection;

        final track = event.track - _clipMoveActionData!.trackOffset;
        final offset = event.offset - _clipMoveActionData!.timeOffset;

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;
        final clips = isSelectionMove
            ? viewModel.selectedClips.map(
                (clipID) => arrangement.clips[clipID]!,
              )
            : [_clipMoveActionData!.clipUnderCursor];

        var snappedOffset = offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.arrangerSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.sequence.defaultTimeSignature,
          timeSignatureChanges: [],
          ticksPerQuarter: project.sequence.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOffset = getSnappedTime(
            rawTime: offset.floor(),
            divisionChanges: divisionChanges,
            round: true,
            startTime: _clipMoveActionData!
                .startTimes[_clipMoveActionData!.clipUnderCursor.id]!,
          );
        }

        var timeOffsetFromEventStart =
            snappedOffset -
            _clipMoveActionData!.startTimes[_clipMoveActionData!
                .clipUnderCursor
                .id]!;
        var trackOffsetFromEventStart =
            track.round() -
            _clipMoveActionData!.startTracks[_clipMoveActionData!
                .clipUnderCursor
                .id]!;

        // Prevent the leftmost track from going earlier than the start of the arrangement
        if (_clipMoveActionData!.startOfFirstClip + timeOffsetFromEventStart <
            0) {
          timeOffsetFromEventStart = -_clipMoveActionData!.startOfFirstClip;
        }

        // Prevent the top key from going above the highest allowed note
        if (_clipMoveActionData!.trackOfTopClip + trackOffsetFromEventStart <
            0) {
          trackOffsetFromEventStart = -_clipMoveActionData!.trackOfTopClip;
        }

        // Prevent the bottom key from going below the lowest allowed note
        if (_clipMoveActionData!.trackOfBottomClip +
                trackOffsetFromEventStart >=
            project.trackOrder.length) {
          trackOffsetFromEventStart =
              project.trackOrder.length -
              1 -
              _clipMoveActionData!.trackOfBottomClip;
        }

        for (final clip in clips) {
          final shift = event.keyboardModifiers.shift;
          final ctrl = event.keyboardModifiers.ctrl;

          final track =
              _clipMoveActionData!.startTracks[clip.id]! +
              (shift ? 0 : trackOffsetFromEventStart);
          clip.trackId = project.trackOrder[track];

          clip.offset =
              _clipMoveActionData!.startTimes[clip.id]! +
              (!shift && ctrl ? 0 : timeOffsetFromEventStart);
        }

        break;
      case EventHandlingState.creatingAdditiveSelectionBox:
      case EventHandlingState.creatingSubtractiveSelectionBox:
        final arrangement =
            project.sequence.arrangements[project.sequence.activeArrangementID];
        if (arrangement == null) return;

        final isSubtractive =
            _eventHandlingState ==
            EventHandlingState.creatingSubtractiveSelectionBox;

        viewModel.selectionBox = Rectangle.fromPoints(
          _selectionBoxActionData!.start,
          Point(event.offset, event.track),
        );

        final clipsInSelection = arrangement.clips.values
            .where((clip) {
              final trackTop = project.trackOrder
                  .indexOf(clip.trackId)
                  .toDouble();

              return viewModel.selectionBox!.intersects(
                Rectangle(clip.offset, trackTop, clip.width, 1),
              );
            })
            .map((clip) => clip.id)
            .toSet();

        if (isSubtractive) {
          viewModel.selectedClips = ObservableSet.of(
            _selectionBoxActionData!.originalSelection.difference(
              clipsInSelection,
            ),
          );
        } else {
          viewModel.selectedClips = ObservableSet.of(
            _selectionBoxActionData!.originalSelection.union(clipsInSelection),
          );
        }

        break;
      case EventHandlingState.deleting:
        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

        final thisPoint = Point(event.offset, event.track);

        final clipsUnderCursorPath = arrangement.clips.values.where((clip) {
          // This might be too inefficient... For each clip, we have to get the
          // index of its track in the track list. This is fine if there's not
          // a lot of clips or not a lot of tracks, or if the clips are all
          // near the top (this last one is pretty likely), but feels not-so-
          // great to me for larger projects. I don't want to prematurely
          // optimize though, so I'm leaving this note for the next weary
          // traveler.
          final clipTrack = project.trackOrder.indexOf(clip.trackId);

          final clipTopLeft = Point(clip.offset, clipTrack);
          final clipBottomRight = Point(
            clip.offset + clip.width,
            clipTrack + 1,
          );

          return rectanglesIntersect(
                Rectangle.fromPoints(
                  _deleteActionData!.mostRecentPoint,
                  thisPoint,
                ),
                Rectangle.fromPoints(clipTopLeft, clipBottomRight),
              ) &&
              lineIntersectsBox(
                _deleteActionData!.mostRecentPoint,
                thisPoint,
                clipTopLeft,
                clipBottomRight,
              );
        }).toList();

        final clipsToRemoveFromIgnore = <ClipModel>[];

        for (final clip in _deleteActionData!.clipsToTemporarilyIgnore) {
          if (!clipsUnderCursorPath.contains(clip)) {
            clipsToRemoveFromIgnore.add(clip);
          }
        }

        for (final clip in clipsToRemoveFromIgnore) {
          _deleteActionData!.clipsToTemporarilyIgnore.remove(clip);
        }

        for (final clip in clipsUnderCursorPath) {
          if (_deleteActionData!.clipsToTemporarilyIgnore.contains(clip)) {
            continue;
          }

          arrangement.clips.remove(clip.id);
          _deleteActionData!.clipsDeleted.add(clip);
          viewModel.selectedClips.remove(clip.id);
        }

        _deleteActionData!.mostRecentPoint = thisPoint;

        break;
      case EventHandlingState.resizingSingleClip:
      case EventHandlingState.resizingSelection:
        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

        var snappedOriginalTime = _clipResizeActionData!.pointerStartOffset
            .floor();
        var snappedEventTime = event.offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.arrangerSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.sequence.defaultTimeSignature,
          timeSignatureChanges: [],
          ticksPerQuarter: project.sequence.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOriginalTime = getSnappedTime(
            rawTime: _clipResizeActionData!.pointerStartOffset.floor(),
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

        final offsetOfSmallestClipAtStart = _clipResizeActionData!
            .startWidths[_clipResizeActionData!.smallestClip]!;

        for (var i = 0; i < divisionChanges.length; i++) {
          if (i < divisionChanges.length - 1 &&
              divisionChanges[i + 1].offset <= offsetOfSmallestClipAtStart) {
            continue;
          }

          snapAtSmallestClipStart = divisionChanges[i].divisionSnapSize;

          break;
        }

        var diff = snappedEventTime - snappedOriginalTime;

        if (_clipResizeActionData!.isFromStartOfClip) {
          diff = -diff; // Means we don't need to modify the calculation below.
        }

        // Make sure no clips go below the smallest snap size if snapping is
        // enabled.
        if (!event.keyboardModifiers.alt &&
            _clipResizeActionData!.smallestStartTimeRange.width + diff <
                snapAtSmallestClipStart) {
          int snapCount =
              ((snapAtSmallestClipStart -
                          (_clipResizeActionData!.smallestStartTimeRange.width +
                              diff)) /
                      snapAtSmallestClipStart)
                  .ceil();
          diff = diff + snapCount * snapAtSmallestClipStart;
        }

        // If snapping is disabled, make sure the clips all have a length of at
        // least 1.
        if (event.keyboardModifiers.alt) {
          final newSmallestClipSize =
              (_clipResizeActionData!.smallestStartTimeRange.width + diff)
                  .round();
          if (newSmallestClipSize < 1) {
            diff += 1 - newSmallestClipSize;
          }
        }

        if (_clipResizeActionData!.isFromStartOfClip) {
          diff = -diff; // Means we don't need to modify the calculation above.
        }

        // Make sure no clips have a time view starting < 0, and that no clips
        // are resized to start before the start of the arrangement.
        if (_clipResizeActionData!.isFromStartOfClip) {
          var firstNewTimeViewStart = maxSafeIntWeb;
          var firstNewOffset = maxSafeIntWeb;

          for (final id in _clipResizeActionData!.startOffsets.keys) {
            final newTimeViewStart =
                _clipResizeActionData!.startTimeViewStarts[id]! + diff;
            if (newTimeViewStart < firstNewTimeViewStart) {
              firstNewTimeViewStart = newTimeViewStart;
            }

            final newOffset = _clipResizeActionData!.startOffsets[id]! + diff;
            if (newOffset < firstNewOffset) {
              firstNewOffset = newOffset;
            }
          }

          if (firstNewTimeViewStart < 0 || firstNewOffset < 0) {
            final correction = -min(firstNewTimeViewStart, firstNewOffset);
            diff += correction;
          }
        }

        for (final clip in arrangement.clips.values.where(
          (clip) => _clipResizeActionData!.startWidths.containsKey(clip.id),
        )) {
          if (clip.timeView == null) {
            final width = _clipResizeActionData!.startWidths[clip.id]!;
            clip.timeView = TimeViewModel(start: 0, end: width);
          }

          if (_clipResizeActionData!.isFromStartOfClip) {
            clip.timeView!.start =
                _clipResizeActionData!.startTimeViewStarts[clip.id]! + diff;
            clip.offset = _clipResizeActionData!.startOffsets[clip.id]! + diff;
          } else {
            clip.timeView!.end =
                clip.timeView!.start +
                _clipResizeActionData!.startWidths[clip.id]! +
                diff;
          }
        }

        if (_eventHandlingState == EventHandlingState.resizingSingleClip ||
            _eventHandlingState == EventHandlingState.resizingSelection) {
          // Update cursor pattern and time range
          viewModel.cursorPattern =
              _clipResizeActionData!.pressedClip.patternId;
          viewModel.cursorTimeRange = _clipResizeActionData!
              .pressedClip
              .timeView
              ?.clone();
        }

        break;
    }
  }

  void pointerUp(ArrangerPointerEvent event) {
    if (project.sequence.activeArrangementID == null) return;

    if (_eventHandlingState == EventHandlingState.movingSingleClip ||
        _eventHandlingState == EventHandlingState.movingSelection) {
      final arrangement =
          project.sequence.arrangements[project.sequence.activeArrangementID]!;
      final clips = arrangement.clips;

      final isSingleClip =
          _eventHandlingState == EventHandlingState.movingSingleClip;

      final relevantClips = isSingleClip
          ? [_clipMoveActionData!.clipUnderCursor]
          : viewModel.selectedClips.map((clipID) => clips[clipID]!).toList();

      final commands = relevantClips.map((clip) {
        return MoveClipCommand(
          arrangementID: arrangement.id,
          clipID: clip.id,
          oldOffset: _clipMoveActionData!.startTimes[clip.id]!,
          newOffset: clip.offset,
          oldTrack:
              project.trackOrder[_clipMoveActionData!.startTracks[clip.id]!],
          newTrack: clip.trackId,
        );
      }).toList();

      project.push(JournalPageCommand(commands));
    } else if (_eventHandlingState == EventHandlingState.deleting) {
      // There should already be an active journal page, so we don't need to
      // collect these manually.
      for (final clip in _deleteActionData!.clipsDeleted) {
        final command = DeleteClipCommand(
          arrangementID: project.sequence.activeArrangementID!,
          clip: clip,
        );

        project.push(command);
      }
    } else if (_eventHandlingState == EventHandlingState.resizingSingleClip ||
        _eventHandlingState == EventHandlingState.resizingSelection) {
      final arrangement =
          project.sequence.arrangements[project.sequence.activeArrangementID]!;

      final commands = _clipResizeActionData!.startWidths.keys.map((id) {
        final clip = arrangement.clips[id]!;
        final oldStart = _clipResizeActionData!.startTimeViewStarts[id]!;
        final oldWidth = _clipResizeActionData!.startWidths[id]!;

        return ResizeClipCommand(
          arrangementID: project.sequence.activeArrangementID!,
          clipID: id,
          oldOffset: _clipResizeActionData!.startOffsets[id]!,
          oldTimeView: TimeViewModel(start: oldStart, end: oldStart + oldWidth),
          newOffset: clip.offset,
          newTimeView:
              clip.timeView?.clone() ??
              TimeViewModel(start: 0, end: clip.width),
        );
      }).toList();

      final command = JournalPageCommand(commands);

      project.push(command);
    }

    _eventHandlingState = EventHandlingState.idle;

    viewModel.selectionBox = null;
    viewModel.pressedClip = null;

    project.commitJournalPage();

    _clipMoveActionData = null;
    _selectionBoxActionData = null;
    _deleteActionData = null;
    _clipResizeActionData = null;
  }
}
