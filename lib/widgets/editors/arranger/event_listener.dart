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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/scroll_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'view_model.dart';
import 'controller/arranger_controller.dart';
import 'events.dart';
import 'helpers.dart';

class ArrangerEventListener extends StatefulWidget {
  final Widget? child;
  final ClipWidgetEventData eventData;

  const ArrangerEventListener({
    Key? key,
    this.child,
    required this.eventData,
  }) : super(key: key);

  @override
  State<ArrangerEventListener> createState() => _ArrangerEventListenerState();
}

class _ArrangerEventListenerState extends State<ArrangerEventListener> {
  var _panYStart = double.nan;
  var _panScrollPosStart = double.nan;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, boxConstraints) {
      return Observer(builder: (context) {
        final viewModel = Provider.of<ArrangerViewModel>(context);
        final controller = Provider.of<ArrangerController>(context);

        return EditorScrollManager(
          timeView: viewModel.timeView,
          onVerticalScrollChange: (pixelDelta) {
            viewModel.verticalScrollPosition =
                (viewModel.verticalScrollPosition +
                        pixelDelta *
                            0.01 *
                            viewModel.baseTrackHeight
                                .clamp(minTrackHeight, maxTrackHeight))
                    .clamp(0, double.infinity);
          },
          onVerticalPanStart: (y) {
            _panYStart = y;
            _panScrollPosStart = viewModel.verticalScrollPosition;
          },
          onVerticalPanMove: (y) {
            final delta = -(y - _panYStart);
            viewModel.verticalScrollPosition =
                (_panScrollPosStart + delta).clamp(0, double.infinity);
          },
          child: Listener(
            onPointerDown: (event) {
              controller.pointerDown(convertPointerEvent(
                  event, boxConstraints.biggest, widget.eventData));
              widget.eventData.reset();
            },
            onPointerMove: (event) {
              controller.pointerMove(convertPointerEvent(
                  event, boxConstraints.biggest, widget.eventData));
              widget.eventData.reset();
            },
            onPointerUp: (event) {
              controller.pointerUp(convertPointerEvent(
                  event, boxConstraints.biggest, widget.eventData));
              widget.eventData.reset();
            },
            onPointerCancel: (event) {
              controller.pointerUp(convertPointerEvent(
                  event, boxConstraints.biggest, widget.eventData));
              widget.eventData.reset();
            },
            child: widget.child,
          ),
        );
      });
    });
  }

  ArrangerPointerEvent convertPointerEvent(
    PointerEvent event,
    Size viewSize,
    ClipWidgetEventData eventData,
  ) {
    final viewModel = Provider.of<ArrangerViewModel>(context, listen: false);
    final project = Provider.of<ProjectModel>(context, listen: false);
    final keyboardModifiers =
        Provider.of<KeyboardModifiers>(context, listen: false);

    final offset = pixelsToTime(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: viewSize.width,
      pixelOffsetFromLeft: event.localPosition.dx,
    );

    final track = posToTrackIndex(
      yOffset: event.localPosition.dy,
      baseTrackHeight: viewModel.baseTrackHeight,
      trackOrder: project.song.trackOrder,
      trackHeightModifiers: viewModel.trackHeightModifiers,
      scrollPosition: viewModel.verticalScrollPosition,
    );

    return ArrangerPointerEvent(
      offset: offset,
      track: track,
      pointerEvent: event,
      arrangerSize: viewSize,
      keyboardModifiers: keyboardModifiers,
      clipUnderCursor: eventData.clipsUnderCursor.firstOrNull,
      isResizeFromStart: eventData.isResizeStartEvent,
      isResizeFromEnd: eventData.isResizeEndEvent,
    );
  }
}

/// A single instance of this class is handed to every clip in the arranger.
/// The fields here are used during event handling.
class ClipWidgetEventData {
  /// Flutter sends pointer events to the innermost [Listener] first, and then
  /// moves up the tree. We use this fact to our advantage here; this list is
  /// passed to all clip widgets, and they have listeners that add their clip
  /// IDs to this list. It is the responsibility of the
  /// [PianoRollEventListener] to clear this list at the end of each event
  /// handler.
  ///
  /// The result is that, during event handling, this list contains a list of
  /// clip IDs for clips that are currently under the pointer.
  List<ID> clipsUnderCursor = [];

  /// True if the cursor is over the start resize handle
  bool isResizeStartEvent = false;

  /// True if the cursor is over the end resize handle
  bool isResizeEndEvent = false;

  /// Resets this class to its original state.
  void reset() {
    clipsUnderCursor.clear();
    isResizeStartEvent = false;
    isResizeEndEvent = false;
  }
}
