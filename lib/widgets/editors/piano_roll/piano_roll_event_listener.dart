/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import 'controller/piano_roll_controller.dart';
import 'helpers.dart';

/// A single instance of this class is handed to every note in the piano roll.
/// The fields here are used during event handling.
class NoteWidgetEventData {
  /// Set to true if the cursor was over a note resize handle during this
  /// event.
  bool isResizeEvent = false;

  /// Flutter sends pointer events to the innermost [Listener] first, and then
  /// moves up the tree. We use this fact to our advantage here; this list is
  /// passed to all note widgets, and they have listeners that add their note
  /// IDs to this list. It is the responsibility of the
  /// [PianoRollEventListener] to clear this list at the end of each event
  /// handler.
  ///
  /// The result is that, during event handling, this list contains a list of
  /// note IDs for notes that are currently under the pointer.
  List<ID> notesUnderCursor = [];

  /// Resets this class to its original state.
  void reset() {
    isResizeEvent = false;
    notesUnderCursor.clear();
  }
}

class PianoRollEventListener extends StatefulWidget {
  final Widget child;

  final NoteWidgetEventData noteWidgetEventData;

  const PianoRollEventListener({
    Key? key,
    required this.child,
    required this.noteWidgetEventData,
  }) : super(key: key);

  @override
  State<PianoRollEventListener> createState() => _PianoRollEventListenerState();
}

class _PianoRollEventListenerState extends State<PianoRollEventListener> {
  handlePointerDown(BuildContext context, PointerDownEvent e) {
    final noteUnderCursor =
        widget.noteWidgetEventData.notesUnderCursor.firstOrNull;

    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      handleMiddlePointerDown(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        keyAtTop: viewModel.keyValueAtTop,
        pointerPos: pointerPos,
      );

      return;
    }

    final controller = Provider.of<PianoRollController>(context, listen: false);

    final note = pixelsToKeyValue(
      keyHeight: viewModel.keyHeight,
      keyValueAtTop: viewModel.keyValueAtTop,
      pixelOffsetFromTop: pointerPos.dy,
    );

    final time = pixelsToTime(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: context.size?.width ?? 1,
      pixelOffsetFromLeft: pointerPos.dx,
    );

    final keyboardModifiers =
        Provider.of<KeyboardModifiers>(context, listen: false);

    final event = PianoRollPointerDownEvent(
      key: note,
      offset: time,
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
      noteUnderCursor: noteUnderCursor,
      keyboardModifiers: keyboardModifiers,
      isResize: widget.noteWidgetEventData.isResizeEvent,
    );

    controller.pointerDown(event);
  }

  handlePointerMove(BuildContext context, PointerMoveEvent e) {
    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      handleMiddlePointerMove(
        model: viewModel,
        e: e,
        pointerPos: pointerPos,
        pianoRollSize: contentRenderBox.size,
      );

      return;
    }

    final controller = Provider.of<PianoRollController>(context, listen: false);

    final keyboardModifiers =
        Provider.of<KeyboardModifiers>(context, listen: false);

    final event = PianoRollPointerMoveEvent(
      key: pixelsToKeyValue(
        keyHeight: viewModel.keyHeight,
        keyValueAtTop: viewModel.keyValueAtTop,
        pixelOffsetFromTop: pointerPos.dy,
      ),
      offset: pixelsToTime(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        viewPixelWidth: context.size?.width ?? 1,
        pixelOffsetFromLeft: pointerPos.dx,
      ),
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
      keyboardModifiers: keyboardModifiers,
    );

    controller.pointerMove(event);
  }

  handlePointerUp(BuildContext context, PointerEvent e) {
    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final controller = Provider.of<PianoRollController>(context, listen: false);
    final keyboardModifiers =
        Provider.of<KeyboardModifiers>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    final event = PianoRollPointerUpEvent(
      key: pixelsToKeyValue(
        keyHeight: viewModel.keyHeight,
        keyValueAtTop: viewModel.keyValueAtTop,
        pixelOffsetFromTop: pointerPos.dy,
      ),
      offset: pixelsToTime(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        viewPixelWidth: context.size?.width ?? 1,
        pixelOffsetFromLeft: pointerPos.dx,
      ),
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
      keyboardModifiers: keyboardModifiers,
    );

    controller.pointerUp(event);
  }

  // Middle-mouse pan

  double _panInitialTimeViewStart = double.nan;
  double _panInitialTimeViewEnd = double.nan;
  double _panInitialX = double.nan;

  double _panInitialKeyAtTop = double.nan;
  double _panInitialY = double.nan;

  handleMiddlePointerDown({
    required double timeViewStart,
    required double timeViewEnd,
    required double keyAtTop,
    required Offset pointerPos,
  }) {
    _panInitialTimeViewStart = timeViewStart;
    _panInitialTimeViewEnd = timeViewEnd;
    _panInitialX = pointerPos.dx;

    _panInitialKeyAtTop = keyAtTop;
    _panInitialY = pointerPos.dy;
  }

  handleMiddlePointerMove({
    required PianoRollViewModel model,
    required PointerMoveEvent e,
    required Offset pointerPos,
    required Size pianoRollSize,
  }) {
    // X

    final deltaX = pointerPos.dx - _panInitialX;
    final deltaTimeSincePanInit =
        (-deltaX / pianoRollSize.width) * model.timeView.width;

    var start = _panInitialTimeViewStart + deltaTimeSincePanInit;
    var end = _panInitialTimeViewEnd + deltaTimeSincePanInit;

    if (start < 0) {
      final delta = -start;
      start += delta;
      end += delta;
    }

    model.timeView.start = start;
    model.timeView.end = end;

    // Y

    final deltaY = pointerPos.dy - _panInitialY;
    final deltaKeySincePanInit = (deltaY / model.keyHeight);

    model.keyValueAtTop = clampDouble(
        _panInitialKeyAtTop + deltaKeySincePanInit,
        minKeyValue + (pianoRollSize.height / model.keyHeight),
        maxKeyValue);
  }

  // Scroll

  handleScroll(PointerScrollEvent e) {
    final delta = e.scrollDelta.dy;

    final modifiers = Provider.of<KeyboardModifiers>(context, listen: false);
    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;

    // Zoom
    if (modifiers.ctrl) {
      final pointerPos = contentRenderBox.globalToLocal(e.position);

      zoomTimeView(
        timeView: viewModel.timeView,
        delta: delta,
        mouseX: pointerPos.dx,
        editorWidth: contentRenderBox.size.width,
      );

      return;
    }

    // Horizontal scroll
    if (modifiers.shift) {
      // We need to scroll by the same speed in pixels, regardless of how
      // zoomed in we are. Since our current scroll position is in time and not
      // pixels, we use this value to convert between the two.
      final ticksPerPixel =
          viewModel.timeView.width / contentRenderBox.size.width;

      const scrollAmountInPixels = 100;

      var scrollAmountInTicks =
          delta * 0.01 * scrollAmountInPixels * ticksPerPixel;

      if (viewModel.timeView.start + scrollAmountInTicks < 0) {
        scrollAmountInTicks = -viewModel.timeView.start;
      }

      viewModel.timeView.start += scrollAmountInTicks;
      viewModel.timeView.end += scrollAmountInTicks;
      return;
    }

    // Vertical scroll
    final keysPerPixel = 1 / viewModel.keyHeight;

    const scrollAmountInPixels = 50;

    final scrollAmountInKeys =
        -delta * 0.01 * scrollAmountInPixels * keysPerPixel;

    viewModel.keyValueAtTop = clampDouble(
        viewModel.keyValueAtTop + scrollAmountInKeys,
        minKeyValue + (contentRenderBox.size.height / viewModel.keyHeight),
        maxKeyValue);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          handleScroll(e);
        }
        widget.noteWidgetEventData.reset();
      },
      onPointerDown: (e) {
        handlePointerDown(context, e);
        widget.noteWidgetEventData.reset();
      },
      onPointerMove: (e) {
        handlePointerMove(context, e);
        widget.noteWidgetEventData.reset();
      },
      onPointerUp: (e) {
        handlePointerUp(context, e);
        widget.noteWidgetEventData.reset();
      },

      // If a middle-click or right-click drag goes out of the window, Flutter
      // will temporarily stop receiving move events. If the button is released
      // while the pointer is outside the window in one of these cases, Flutter
      // will call onPointerCancel instead of onPointerUp.
      //
      // We send this to the controller as a pointer up event. If
      // onPointerCancel is called, we will not receive a pointer up event. An
      // event cycle must always contain down, then zero or more moves, then
      // up, and always in that order. We must always finalize the drag and
      // create any necessary undo steps for whatever action has been
      // performed, and we must always do this before starting another drag.
      onPointerCancel: (e) {
        handlePointerUp(context, e);
        widget.noteWidgetEventData.reset();
      },
      child: widget.child,
    );
  }
}
