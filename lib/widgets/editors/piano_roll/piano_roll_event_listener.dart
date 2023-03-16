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
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/main_window/main_window_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import 'helpers.dart';

class PianoRollEventListener extends StatefulWidget {
  final Widget child;

  /// Flutter sends pointer events to the innermost [Listener] first, and then
  /// moves up the tree. We use this fact to our advantage here; this list is
  /// passed to all note widgets, and they have listeners that add their note
  /// IDs to this list. It is the responsibility of the
  /// [PianoRollEventListener] to clear this list at the end of each event
  /// handler.
  ///
  /// The result is that, during event handling, this list contains a list of
  /// note IDs for notes that are currently under the pointer.
  final List<ID> notesUnderCursor;

  const PianoRollEventListener({
    Key? key,
    required this.child,
    required this.notesUnderCursor,
  }) : super(key: key);

  @override
  State<PianoRollEventListener> createState() => _PianoRollEventListenerState();
}

class _PianoRollEventListenerState extends State<PianoRollEventListener> {
  handlePointerDown(BuildContext context, PointerDownEvent e) {
    final noteUnderCursor = widget.notesUnderCursor.firstOrNull;

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

    final event = PianoRollPointerDownEvent(
      key: note,
      offset: time,
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
      noteUnderCursor: noteUnderCursor,
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

    final event = PianoRollPointerMoveEvent(
      key: pixelsToKeyValue(
          keyHeight: viewModel.keyHeight,
          keyValueAtTop: viewModel.keyValueAtTop,
          pixelOffsetFromTop: pointerPos.dy),
      offset: pixelsToTime(
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
          viewPixelWidth: context.size?.width ?? 1,
          pixelOffsetFromLeft: pointerPos.dx),
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
    );

    controller.pointerMove(event);
  }

  handlePointerUp(BuildContext context, PointerUpEvent e) {
    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final controller = Provider.of<PianoRollController>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    final event = PianoRollPointerUpEvent(
      key: pixelsToKeyValue(
          keyHeight: viewModel.keyHeight,
          keyValueAtTop: viewModel.keyValueAtTop,
          pixelOffsetFromTop: pointerPos.dy),
      offset: pixelsToTime(
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
          viewPixelWidth: context.size?.width ?? 1,
          pixelOffsetFromLeft: pointerPos.dx),
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
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

    const scrollAmountInPixels = 100;

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
        widget.notesUnderCursor.clear();
      },
      onPointerDown: (e) {
        handlePointerDown(context, e);
        widget.notesUnderCursor.clear();
      },
      onPointerMove: (e) {
        handlePointerMove(context, e);
        widget.notesUnderCursor.clear();
      },
      onPointerUp: (e) {
        handlePointerUp(context, e);
        widget.notesUnderCursor.clear();
      },
      child: widget.child,
    );
  }
}
