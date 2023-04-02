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
}

mixin _ArrangerPointerEventsMixin on _ArrangerController {
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
  }

  void pointerUp(ArrangerPointerEvent event) {
    if (project.song.activeArrangementID == null) return;

    project.commitJournalPage();
  }
}
