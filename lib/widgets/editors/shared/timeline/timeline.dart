/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'dart:math';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline_notifications.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../helpers/time_helpers.dart';
import '../helpers/types.dart';

const _playheadHandleSize = Size(15, 15);
const _loopAreaHeight = 17.0;

/// Draws the timeline for editors.
class Timeline extends StatefulWidget {
  final Id? arrangementID;
  final Id? patternID;

  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;

  const Timeline.pattern({
    super.key,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.patternID,
  }) : arrangementID = null;

  const Timeline.arrangement({
    super.key,
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.arrangementID,
  }) : patternID = null;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> with TickerProviderStateMixin {
  late Size _lastTimelineSize;
  DateTime? _lastMouseDownTime;

  bool _playheadMoveActive = false;
  double? _lastPlayheadPositionSet;

  bool _loopCreateActive = false;
  int? _loopCreateStart;

  // During event handling, if the start or end loop markers are pressed before
  // the event reaches the timeline, one of these will be set to true.
  bool _loopStartPressed = false;
  bool _loopEndPressed = false;

  bool _loopHandleMoveActive = false;
  int _loopHandleMoveTimeAtEventStart = 0;

  PatternModel? get _pattern {
    final project = Provider.of<ProjectModel>(context, listen: false);
    return project.sequence.patterns[widget.patternID];
  }

  ArrangementModel? get _arrangement {
    final project = Provider.of<ProjectModel>(context, listen: false);
    return project.sequence.arrangements[widget.arrangementID];
  }

  void _setPlayheadPosition(
    double time,
    bool ignoreSnap, {
    /* ArrangementModel? arrangement, */ PatternModel? pattern,
  }) {
    final project = Provider.of<ProjectModel>(context, listen: false);

    var targetTime = time.round();

    if (!ignoreSnap) {
      final divisionChanges = getDivisionChanges(
        viewWidthInPixels: _lastTimelineSize.width,
        snap: AutoSnap(),
        defaultTimeSignature: project.sequence.defaultTimeSignature,
        timeSignatureChanges: /* arrangement?.timeSignatureChanges ?? */
            pattern?.timeSignatureChanges ?? [],
        ticksPerQuarter: project.sequence.ticksPerQuarter,
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        minPixelsPerSection: minorMinPixels,
      );

      targetTime = getSnappedTime(
        rawTime: time.toInt(),
        divisionChanges: divisionChanges,
        round: true,
      );
    }

    if (!project.sequence.isPlaying &&
        project.sequence.playbackStartPosition != targetTime) {
      project.sequence.playbackStartPosition = targetTime;
    }

    if (_lastPlayheadPositionSet != targetTime) {
      final asDouble = targetTime.toDouble();
      if (project.engine.engineState == EngineState.running) {
        project.engine.sequencerApi.jumpPlayheadTo(asDouble);
      }
      _lastPlayheadPositionSet = asDouble;
    }
  }

  void handlePointerDown(PointerEvent event) {
    final arrangement = _arrangement;
    final pattern = _pattern;

    final deltaSinceLastMouseDown = _lastMouseDownTime == null
        ? Duration(days: 1)
        : DateTime.now().difference(_lastMouseDownTime!);
    final isDoubleClick =
        deltaSinceLastMouseDown.inMilliseconds < 500 &&
        event.buttons & kPrimaryButton != 0;
    _lastMouseDownTime = DateTime.now();

    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );

    final isPlayheadMove =
        event.buttons & kPrimaryButton != 0 &&
        event.localPosition.dy > _loopAreaHeight;

    final isLoopHandleMove =
        (event.buttons & kPrimaryButton != 0 &&
        !isDoubleClick &&
        (_loopStartPressed || _loopEndPressed));

    final isLoopCreate =
        (isDoubleClick ||
            (event.buttons & kSecondaryButton != 0) ||
            (event.buttons & kPrimaryButton != 0 && keyboardModifiers.ctrl)) &&
        event.localPosition.dy <= _loopAreaHeight;

    if (isPlayheadMove) {
      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      _setPlayheadPosition(time, keyboardModifiers.alt, pattern: pattern);

      _playheadMoveActive = true;
    } else if (isLoopHandleMove) {
      if (arrangement == null && pattern == null) {
        // If there is no arrangement or pattern, we can't move the loop handle
        return;
      }

      _loopHandleMoveActive = true;

      if (_loopStartPressed) {
        _loopHandleMoveTimeAtEventStart =
            arrangement?.loopPoints?.start ?? pattern?.loopPoints?.start ?? 0;
      } else if (_loopEndPressed) {
        _loopHandleMoveTimeAtEventStart =
            arrangement?.loopPoints?.end ?? pattern?.loopPoints?.end ?? 0;
      }
    } else if (isLoopCreate) {
      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      if (keyboardModifiers.alt) {
        _loopCreateStart = time.round();
      } else {
        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: _lastTimelineSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.defaultTimeSignature,
          timeSignatureChanges: /* arrangement?.timeSignatureChanges ?? */
              pattern?.timeSignatureChanges ?? [],
          ticksPerQuarter: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.ticksPerQuarter,
          timeViewStart: widget.timeViewStartAnimation.value,
          timeViewEnd: widget.timeViewEndAnimation.value,
          minPixelsPerSection: minorMinPixels,
        );

        _loopCreateStart = getSnappedTime(
          rawTime: time.toInt(),
          divisionChanges: divisionChanges,
          round: true,
        );

        _arrangement?.loopPoints = null;
        _pattern?.loopPoints = null;
      }

      _loopCreateActive = true;
    }
  }

  void handlePointerMove(PointerEvent event) {
    final arrangement = _arrangement;
    final pattern = _pattern;

    final keyboardModifiers = Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    );

    if (_playheadMoveActive) {
      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      _setPlayheadPosition(time, keyboardModifiers.alt, pattern: pattern);
    } else if (_loopHandleMoveActive) {
      if (arrangement == null && pattern == null) {
        // If there is no arrangement or pattern, we can't move the loop handle
        return;
      }

      final loopPoints = arrangement?.loopPoints ?? pattern?.loopPoints;

      if (loopPoints == null) {
        // If this happens it's probably a bug
        return;
      }

      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      if (!keyboardModifiers.alt) {
        var divisionChanges = getDivisionChanges(
          viewWidthInPixels: _lastTimelineSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.defaultTimeSignature,
          timeSignatureChanges: /* arrangement?.timeSignatureChanges ?? */
              pattern?.timeSignatureChanges ?? [],
          ticksPerQuarter: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.ticksPerQuarter,
          timeViewStart: widget.timeViewStartAnimation.value,
          timeViewEnd: widget.timeViewEndAnimation.value,
          minPixelsPerSection: minorMinPixels,
        );

        time = getSnappedTime(
          rawTime: time.toInt(),
          divisionChanges: divisionChanges,
          round: true,
          startTime: _loopHandleMoveTimeAtEventStart,
        ).toDouble();
      }

      if (_loopStartPressed) {
        if (time >= loopPoints.end) {
          // This would be invalid
          return;
        }

        loopPoints.start = time.round();
      } else if (_loopEndPressed) {
        if (time <= loopPoints.start) {
          // This would be invalid
          return;
        }

        loopPoints.end = time.round();
      }
    } else if (_loopCreateActive) {
      if (arrangement == null && pattern == null) {
        // If there is no arrangement or pattern, we can't create a loop
        return;
      }

      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      if (!keyboardModifiers.alt) {
        var divisionChanges = getDivisionChanges(
          viewWidthInPixels: _lastTimelineSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.defaultTimeSignature,
          timeSignatureChanges: /* arrangement?.timeSignatureChanges ?? */
              pattern?.timeSignatureChanges ?? [],
          ticksPerQuarter: Provider.of<ProjectModel>(
            context,
            listen: false,
          ).sequence.ticksPerQuarter,
          timeViewStart: widget.timeViewStartAnimation.value,
          timeViewEnd: widget.timeViewEndAnimation.value,
          minPixelsPerSection: minorMinPixels,
        );

        time = getSnappedTime(
          rawTime: time.toInt(),
          divisionChanges: divisionChanges,
          round: true,
        ).toDouble();
      }

      var loopStart = _loopCreateStart!;
      var loopEnd = time.round();

      if (loopStart == loopEnd) {
        arrangement?.loopPoints = null;
        pattern?.loopPoints = null;
        return;
      }

      if (loopStart > loopEnd) {
        // If the start is after the end, swap them
        final temp = loopStart;
        loopStart = loopEnd;
        loopEnd = temp;
      }

      if (arrangement?.loopPoints == null && pattern?.loopPoints == null) {
        arrangement?.loopPoints = LoopPointsModel(loopStart, loopEnd);
        pattern?.loopPoints = LoopPointsModel(loopStart, loopEnd);
      } else {
        arrangement?.loopPoints?.start = loopStart;
        arrangement?.loopPoints?.end = loopEnd;
        pattern?.loopPoints?.start = loopStart;
        pattern?.loopPoints?.end = loopEnd;
      }
    }
  }

  void handlePointerUp(PointerEvent event) {
    _playheadMoveActive = false;
    _lastPlayheadPositionSet = null;

    _loopCreateActive = false;
    _loopCreateStart = null;

    _loopHandleMoveActive = false;
    _loopStartPressed = false;
    _loopEndPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastTimelineSize = constraints.biggest;

        final timeView = context.watch<TimeRange>();
        final project = Provider.of<ProjectModel>(context);

        List<TimeSignatureChangeModel> getTimeSignatureChanges() =>
            project.sequence.patterns[widget.patternID]?.timeSignatureChanges ??
            [];

        void handleScroll(double delta, double mouseX) {
          zoomTimeView(
            timeView: timeView,
            delta: delta,
            mouseX: mouseX,
            editorWidth: constraints.maxWidth,
          );
        }

        return Listener(
          onPointerPanZoomUpdate: (event) {
            handleScroll(-event.panDelta.dy / 2, event.localPosition.dx);
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              handleScroll(event.scrollDelta.dy, event.localPosition.dx);
            }
          },
          onPointerDown: handlePointerDown,
          onPointerMove: handlePointerMove,
          onPointerUp: handlePointerUp,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Container(
                  color: Theme.panel.accent,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: widget.timeViewAnimationController,
                      builder: (context, child) {
                        return Observer(
                          builder: (context) {
                            return CustomPaint(
                              painter: TimelinePainter(
                                timeViewStart:
                                    widget.timeViewStartAnimation.value,
                                timeViewEnd: widget.timeViewEndAnimation.value,
                                ticksPerQuarter:
                                    project.sequence.ticksPerQuarter,
                                defaultTimeSignature:
                                    project.sequence.defaultTimeSignature,
                                timeSignatureChanges: getTimeSignatureChanges(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Observer(
                  builder: (context) {
                    final timelineLabels =
                        project
                            .sequence
                            .patterns[widget.patternID]
                            ?.timeSignatureChanges
                            .map<Widget>(
                              (change) => LayoutId(
                                id: change.offset,
                                child: TimelineLabel(
                                  text: change.timeSignature.toDisplayString(),
                                  id: change.id,
                                  offset: change.offset,
                                  timelineWidth: constraints.maxWidth,
                                  stableBuildContext: context,
                                ),
                              ),
                            )
                            .toList() ??
                        [];

                    return AnimatedBuilder(
                      animation: widget.timeViewAnimationController,
                      builder: (context, child) {
                        return Observer(
                          builder: (context) {
                            return CustomMultiChildLayout(
                              delegate: TimeSignatureLabelLayoutDelegate(
                                timeSignatureChanges: getTimeSignatureChanges(),
                                timeViewStart:
                                    widget.timeViewStartAnimation.value,
                                timeViewEnd: widget.timeViewEndAnimation.value,
                              ),
                              children: timelineLabels,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                Observer(
                  builder: (context) {
                    final loopPoints =
                        _arrangement?.loopPoints ?? _pattern?.loopPoints;
                    return _LoopHandles(
                      timeViewAnimationController:
                          widget.timeViewAnimationController,
                      timeViewStartAnimation: widget.timeViewStartAnimation,
                      timeViewEndAnimation: widget.timeViewEndAnimation,
                      timelineSize: constraints.biggest,
                      loopStart: loopPoints?.start,
                      loopEnd: loopPoints?.end,
                      onLoopStartPressed: () {
                        _loopStartPressed = true;
                      },
                      onLoopEndPressed: () {
                        _loopEndPressed = true;
                      },
                    );
                  },
                ),
                Observer(
                  // project.sequence.activeArrangementID is accessed
                  // conditionally, so this warns sometimes if we don't disable
                  // it
                  warnWhenNoObservables: false,
                  builder: (context) {
                    return Visibility(
                      visible:
                          (widget.patternID != null &&
                              widget.patternID ==
                                  project.sequence.activePatternID) ||
                          (widget.arrangementID != null &&
                              widget.arrangementID ==
                                  project.sequence.activeArrangementID),
                      child: _PlayheadPositioner(
                        timeViewAnimationController:
                            widget.timeViewAnimationController,
                        timeViewStartAnimation: widget.timeViewStartAnimation,
                        timeViewEndAnimation: widget.timeViewEndAnimation,
                        timelineSize: constraints.biggest,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
                  style: TextStyle(color: Theme.text.main),
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

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.defaultTimeSignature,
    required this.timeSignatureChanges,
  });

  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final TimeSignatureModel defaultTimeSignature;
  final List<TimeSignatureChangeModel> timeSignatureChanges;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a bottom border - we don't make this a separate widget because we
    // want to draw the playhead line on top of it.
    final borderPaint = Paint()
      ..color = Theme.panel.border
      ..style = PaintingStyle.fill;

    final markerPaint = Paint()
      ..color = Theme.grid.minor
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      borderPaint,
    );

    // Line to separate numbers and tick marks
    canvas.drawRect(
      Rect.fromLTWH(0, _loopAreaHeight, size.width, 1),
      borderPaint,
    );

    final minorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: minorMinPixels,
      snap: AutoSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: minorDivisionChanges,
      size: size,
      paint: markerPaint,
      height: 5,
    );

    final majorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: majorMinPixels,
      snap: AutoSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,

      // When zoomed in, this means major tick marks will always be drawn less
      // frequently than minor tick marks.
      skipBottomNDivisions: 1,
    );

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: majorDivisionChanges,
      size: size,
      paint: markerPaint,
      height: 13,
    );

    var barDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: barMinPixels,
      snap: BarSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    var i = 0;
    var timePtr = 0;
    var barNumber = barDivisionChanges[0].startLabel;

    barNumber +=
        (timePtr /
                (barDivisionChanges[0].divisionRenderSize /
                    barDivisionChanges[0].distanceBetween))
            .floor();

    while (timePtr < timeViewEnd) {
      // This shouldn't happen, but safety first
      if (i >= barDivisionChanges.length) break;

      final thisDivision = barDivisionChanges[i];
      var nextDivisionStart = 0x7FFF_FFFF_FFFF_FFFF; // int max

      if (i < barDivisionChanges.length - 1) {
        nextDivisionStart = barDivisionChanges[i + 1].offset;
      }

      while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: timePtr.toDouble(),
        );

        // Don't draw numbers that are off-screen
        if (x >= -50) {
          // Vertical line for bar - skip bar 1, because it looks weird
          if (barNumber > 1) {
            canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), markerPaint);
          }

          // Bar number
          TextSpan span = TextSpan(
            style: TextStyle(
              color: Theme.text.main,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            text: barNumber.toString(),
          );
          TextPainter textPainter = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x + 5, 1));
        }

        timePtr += thisDivision.divisionRenderSize;
        barNumber += thisDivision.distanceBetween;

        // If this is true, then this is the last iteration of the inner loop
        if (timePtr >= nextDivisionStart) {
          timePtr = nextDivisionStart;
          barNumber = barDivisionChanges[i + 1].startLabel;
        }
      }

      i++;
    }
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) {
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.ticksPerQuarter != ticksPerQuarter ||
        oldDelegate.defaultTimeSignature != defaultTimeSignature ||
        oldDelegate.timeSignatureChanges != timeSignatureChanges;
  }

  @override
  bool shouldRebuildSemantics(TimelinePainter oldDelegate) => false;
}

Path _getPlayheadHandlePath() {
  final handlePath1 = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, _playheadHandleSize.width, 8),
        Radius.circular(2),
      ),
    );

  final rotatedRectSideLength = sqrt(
    _playheadHandleSize.width * _playheadHandleSize.width / 2,
  );
  final posOffsetForRotate =
      (_playheadHandleSize.width - rotatedRectSideLength) / 2;

  final rRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      posOffsetForRotate,
      4 - posOffsetForRotate,
      rotatedRectSideLength,
      rotatedRectSideLength,
    ),
    Radius.circular(2),
  );
  final handlePath2 = Path()..addRRect(rRect);

  final center = rRect.center;
  final angle = pi / 4; // 45°

  // Build a 4×4 rotation matrix about `center`
  final rotationMatrix = Matrix4.identity()
    ..translate(center.dx, center.dy)
    ..rotateZ(angle)
    ..translate(-center.dx, -center.dy);

  return Path.combine(
    PathOperation.union,
    handlePath1,
    handlePath2.transform(rotationMatrix.storage),
  );
}

final _playheadHandlePath = _getPlayheadHandlePath();

class _PlayheadPositioner extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Size timelineSize;

  const _PlayheadPositioner({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timelineSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timeViewAnimationController,
      builder: (context, child) {
        return VisualizationBuilder(
          config: VisualizationSubscriptionConfig.latest('playhead'),
          builder: (context, playheadPosition) {
            final timeViewStart = timeViewStartAnimation.value;
            final timeViewEnd = timeViewEndAnimation.value;

            final playheadX = timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: timelineSize.width,
              time: playheadPosition,
            );

            return Positioned(
              left: playheadX - (_playheadHandleSize.width) / 2,
              top: timelineSize.height - _playheadHandleSize.height,
              child: CustomPaint(
                size: _playheadHandleSize,
                painter: _PlayheadHandlePainter(),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayheadHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final handlePaint = Paint()
      ..color = Color(0xFFFFFFFF).withAlpha(255 * 4 ~/ 10)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Color(0xFFD9D9D9)
      ..style = PaintingStyle.fill;

    canvas.drawPath(_playheadHandlePath, handlePaint);
    canvas.drawRect(
      Rect.fromLTWH((size.width - 1) / 2, 0, 1, size.height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_PlayheadHandlePainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(_PlayheadHandlePainter oldDelegate) => false;
}

class _LoopHandles extends StatelessWidget {
  final AnimationController timeViewAnimationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final Size timelineSize;
  final int? loopStart;
  final int? loopEnd;

  final void Function() onLoopStartPressed;
  final void Function() onLoopEndPressed;

  const _LoopHandles({
    required this.timeViewAnimationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timelineSize,
    required this.loopStart,
    required this.loopEnd,
    required this.onLoopStartPressed,
    required this.onLoopEndPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timeViewAnimationController,
      builder: (context, child) {
        final timeViewStart = timeViewStartAnimation.value;
        final timeViewEnd = timeViewEndAnimation.value;

        final loopStartX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: timelineSize.width,
          time: loopStart?.toDouble() ?? 0.0,
        );

        final loopEndX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: timelineSize.width,
          time: loopEnd?.toDouble() ?? 0.0,
        );

        final handleInteractSize = 16.0;
        final handleSize = 3.0;

        return Visibility(
          visible: loopStart != null && loopEnd != null,
          child: Positioned(
            left: loopStartX - handleInteractSize / 2,
            top: 0,
            child: SizedBox(
              width: loopEndX - loopStartX + handleInteractSize,
              height: _loopAreaHeight,
              child: Stack(
                children: [
                  // Main loop area
                  Positioned(
                    left: handleInteractSize / 2 + handleSize / 2,
                    right: handleInteractSize / 2 + handleSize / 2,
                    top: 0,
                    bottom: 0,
                    child: Container(color: Color(0xFF20A888).withAlpha(63)),
                  ),

                  // Loop start handle
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: handleInteractSize,
                      child: Listener(
                        onPointerDown: (event) {
                          onLoopStartPressed();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Center(
                            child: Container(
                              width: handleSize,
                              height: _loopAreaHeight,
                              color: Color(0xFF20A888).withAlpha(200),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loop end handle
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: handleInteractSize,
                      child: Listener(
                        onPointerDown: (event) {
                          onLoopEndPressed();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Center(
                            child: Container(
                              width: handleSize,
                              height: _loopAreaHeight,
                              color: Color(0xFF20A888).withAlpha(200),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
