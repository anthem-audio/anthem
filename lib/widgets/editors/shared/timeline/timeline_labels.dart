/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class TimeSignatureLabelLayoutDelegate extends MultiChildLayoutDelegate {
  TimeSignatureLabelLayoutDelegate({
    required this.timeSignatureChanges,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  List<TimeSignatureChangeModel> timeSignatureChanges;
  double timeViewStart;
  double timeViewEnd;

  @override
  void performLayout(Size size) {
    for (var change in timeSignatureChanges) {
      layoutChild(
        change.offset,
        BoxConstraints(maxWidth: size.width, maxHeight: size.height),
      );

      var x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: change.offset.toDouble(),
      );

      positionChild(
        change.offset,
        Offset(x - _labelHandleMouseAreaPadding, 21),
      );
    }
  }

  @override
  bool shouldRelayout(TimeSignatureLabelLayoutDelegate oldDelegate) {
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.timeSignatureChanges != timeSignatureChanges;
  }
}

const _labelHandleWidth = 2.0;
const _labelHandleMouseAreaPadding = 5.0;

class TimelineLabel extends StatefulWidget {
  final String text;
  final Id id;
  final Time offset;
  final double timelineWidth;
  // We need to pass in the parent's build context, since our build context
  // doesn't stay valid during event handling.
  final BuildContext stableBuildContext;

  const TimelineLabel({
    super.key,
    required this.text,
    required this.id,
    required this.offset,
    required this.timelineWidth,
    required this.stableBuildContext,
  });

  @override
  State<TimelineLabel> createState() => _TimelineLabelState();
}

class _TimelineLabelState extends State<TimelineLabel> {
  double pointerStart = 0;
  Time timeStart = 0;

  void onPointerDown(PointerEvent e) {
    pointerStart = e.position.dx;
    timeStart = widget.offset;
    TimelineLabelPointerDownNotification(
      time: widget.offset.toDouble(),
      labelID: widget.id,
      labelType: TimelineLabelType.timeSignatureChange,
      viewWidthInPixels: widget.timelineWidth,
    ).dispatch(widget.stableBuildContext);
  }

  void onPointerMove(PointerEvent e) {
    final timeView = Provider.of<TimeRange>(
      widget.stableBuildContext,
      listen: false,
    );
    final time =
        (e.position.dx - pointerStart) * timeView.width / widget.timelineWidth;
    TimelineLabelPointerMoveNotification(
      time: time,
      labelID: widget.id,
      labelType: TimelineLabelType.timeSignatureChange,
      viewWidthInPixels: widget.timelineWidth,
    ).dispatch(widget.stableBuildContext);
  }

  void onPointerUp(PointerEvent e) {
    final timeView = Provider.of<TimeRange>(
      widget.stableBuildContext,
      listen: false,
    );
    final time =
        (e.position.dx - pointerStart) * timeView.width / widget.timelineWidth;
    TimelineLabelPointerUpNotification(
      time: time,
      labelID: widget.id,
      labelType: TimelineLabelType.timeSignatureChange,
      viewWidthInPixels: widget.timelineWidth,
    ).dispatch(widget.stableBuildContext);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _labelHandleMouseAreaPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.6),
                width: _labelHandleWidth,
                height: 21,
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(3),
                  ),
                ),
                padding: const EdgeInsets.only(left: 4, right: 4),
                height: 21,
                child: Text(
                  widget.text,
                  style: TextStyle(color: AnthemTheme.text.main),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: onPointerDown,
              onPointerMove: onPointerMove,
              onPointerUp: onPointerUp,
              onPointerCancel: onPointerUp,
              child: const SizedBox(width: 12),
            ),
          ),
        ),
      ],
    );
  }
}
