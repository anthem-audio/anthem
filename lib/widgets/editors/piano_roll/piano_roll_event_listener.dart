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

import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import 'helpers.dart';

class PianoRollEventListener extends StatefulWidget {
  final Widget child;

  const PianoRollEventListener({Key? key, required this.child})
      : super(key: key);

  @override
  State<PianoRollEventListener> createState() => _PianoRollEventListenerState();
}

class _PianoRollEventListenerState extends State<PianoRollEventListener> {
  handlePointerDown(BuildContext context, PointerDownEvent e) {
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
      note: note,
      time: time,
      event: e,
      pianoRollSize: contentRenderBox.size,
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
      note: pixelsToKeyValue(
          keyHeight: viewModel.keyHeight,
          keyValueAtTop: viewModel.keyValueAtTop,
          pixelOffsetFromTop: pointerPos.dy),
      time: pixelsToTime(
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
          viewPixelWidth: context.size?.width ?? 1,
          pixelOffsetFromLeft: pointerPos.dx),
      event: e,
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
      note: pixelsToKeyValue(
          keyHeight: viewModel.keyHeight,
          keyValueAtTop: viewModel.keyValueAtTop,
          pixelOffsetFromTop: pointerPos.dy),
      time: pixelsToTime(
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
          viewPixelWidth: context.size?.width ?? 1,
          pixelOffsetFromLeft: pointerPos.dx),
      event: e,
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

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        handlePointerDown(context, e);
      },
      onPointerMove: (e) {
        handlePointerMove(context, e);
      },
      onPointerUp: (e) {
        handlePointerUp(context, e);
      },
      child: widget.child,
    );
  }
}
