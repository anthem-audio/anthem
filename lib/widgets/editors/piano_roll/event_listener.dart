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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import '../shared/scroll_manager.dart';
import 'controller/piano_roll_controller.dart';
import 'helpers.dart';

class PianoRollEventListener extends StatefulWidget {
  final Widget child;

  const PianoRollEventListener({super.key, required this.child});

  @override
  State<PianoRollEventListener> createState() => _PianoRollEventListenerState();
}

class _PianoRollEventListenerState extends State<PianoRollEventListener> {
  void handlePointerDown(BuildContext context, PointerDownEvent e) {
    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      return;
    }

    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    final controller = Provider.of<PianoRollController>(context, listen: false);

    final (
      note: noteUnderCursor,
      resizeHandle: resizeHandleUnderCursor,
    ) = viewModel.getContentUnderCursor(e.localPosition);

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

    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );

    final event = PianoRollPointerDownEvent(
      key: note,
      offset: time,
      pointerEvent: e,
      pianoRollSize: contentRenderBox.size,
      noteUnderCursor:
          noteUnderCursor?.metadata.id ?? resizeHandleUnderCursor?.metadata.id,
      keyboardModifiers: keyboardModifiers,
      isResize: resizeHandleUnderCursor != null,
    );

    controller.pointerDown(event);
  }

  void handlePointerMove(BuildContext context, PointerMoveEvent e) {
    if (e.buttons & kMiddleMouseButton == kMiddleMouseButton) {
      return;
    }

    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pointerPos = contentRenderBox.globalToLocal(e.position);

    final controller = Provider.of<PianoRollController>(context, listen: false);

    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );

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

  void handlePointerUp(BuildContext context, PointerEvent e) {
    final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
    final controller = Provider.of<PianoRollController>(context, listen: false);
    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );
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

  var _panPointerYStart = double.nan;
  var _panKeyAtTopStart = double.nan;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        return Observer(
          builder: (context) {
            return EditorScrollManager(
              timeView: viewModel.timeView,
              onVerticalScrollChange: (pixelDelta) {
                final keysPerPixel = 1 / viewModel.keyHeight;

                final scrollAmountInKeys = -pixelDelta * 0.5 * keysPerPixel;

                viewModel.keyValueAtTop = clampDouble(
                  viewModel.keyValueAtTop + scrollAmountInKeys,
                  minKeyValue +
                      (boxConstraints.maxHeight / viewModel.keyHeight),
                  maxKeyValue,
                );
              },
              onVerticalPanStart: (y) {
                _panPointerYStart = y;
                _panKeyAtTopStart = viewModel.keyValueAtTop;
              },
              onVerticalPanMove: (y) {
                final deltaY = y - _panPointerYStart;
                final deltaKeySincePanInit = (deltaY / viewModel.keyHeight);

                viewModel.keyValueAtTop =
                    (_panKeyAtTopStart + deltaKeySincePanInit).clamp(
                      minKeyValue +
                          (boxConstraints.maxHeight / viewModel.keyHeight),
                      maxKeyValue,
                    );
              },
              child: Listener(
                onPointerDown: (e) {
                  handlePointerDown(context, e);
                },
                onPointerMove: (e) {
                  handlePointerMove(context, e);
                },
                onPointerUp: (e) {
                  handlePointerUp(context, e);
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
                },
                child: widget.child,
              ),
            );
          },
        );
      },
    );
  }
}
