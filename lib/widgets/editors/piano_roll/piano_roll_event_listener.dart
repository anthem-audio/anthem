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

import 'package:anthem/widgets/editors/piano_roll/piano_roll_notifications.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import '../shared/helpers/types.dart';
import 'helpers.dart';

class PianoRollEventListener extends StatelessWidget {
  final Widget child;

  const PianoRollEventListener({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    handlePointerDown(PointerDownEvent e) {
      final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
      final timeView = Provider.of<TimeView>(context, listen: false);
      final contentRenderBox = context.findRenderObject() as RenderBox;
      final pointerPos = contentRenderBox.globalToLocal(e.position);

      PianoRollPointerDownNotification(
        note: pixelsToKeyValue(
            keyHeight: viewModel.keyHeight,
            keyValueAtTop: viewModel.keyValueAtTop,
            pixelOffsetFromTop: pointerPos.dy),
        time: pixelsToTime(
            timeViewStart: timeView.start,
            timeViewEnd: timeView.end,
            viewPixelWidth: context.size?.width ?? 1,
            pixelOffsetFromLeft: pointerPos.dx),
        event: e,
        pianoRollSize: contentRenderBox.size,
      ).dispatch(context);
    }

    handlePointerMove(PointerMoveEvent e) {
      final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
      final timeView = Provider.of<TimeView>(context, listen: false);
      final contentRenderBox = context.findRenderObject() as RenderBox;
      final pointerPos = contentRenderBox.globalToLocal(e.position);

      PianoRollPointerMoveNotification(
        note: pixelsToKeyValue(
            keyHeight: viewModel.keyHeight,
            keyValueAtTop: viewModel.keyValueAtTop,
            pixelOffsetFromTop: pointerPos.dy),
        time: pixelsToTime(
            timeViewStart: timeView.start,
            timeViewEnd: timeView.end,
            viewPixelWidth: context.size?.width ?? 1,
            pixelOffsetFromLeft: pointerPos.dx),
        event: e,
        pianoRollSize: contentRenderBox.size,
      ).dispatch(context);
    }

    handlePointerUp(PointerUpEvent e) {
      final viewModel = Provider.of<PianoRollViewModel>(context, listen: false);
      final timeView = Provider.of<TimeView>(context, listen: false);
      final contentRenderBox = context.findRenderObject() as RenderBox;
      final pointerPos = contentRenderBox.globalToLocal(e.position);

      PianoRollPointerUpNotification(
        note: pixelsToKeyValue(
            keyHeight: viewModel.keyHeight,
            keyValueAtTop: viewModel.keyValueAtTop,
            pixelOffsetFromTop: pointerPos.dy),
        time: pixelsToTime(
            timeViewStart: timeView.start,
            timeViewEnd: timeView.end,
            viewPixelWidth: context.size?.width ?? 1,
            pixelOffsetFromLeft: pointerPos.dx),
        event: e,
        pianoRollSize: contentRenderBox.size,
      ).dispatch(context);
    }

    return Listener(
      onPointerDown: handlePointerDown,
      onPointerMove: handlePointerMove,
      onPointerUp: handlePointerUp,
      child: child,
    );
  }
}
