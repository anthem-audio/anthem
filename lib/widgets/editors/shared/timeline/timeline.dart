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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../helpers/time_helpers.dart';
import '../helpers/types.dart';
import 'loop_indicator.dart';
import 'playhead_handle.dart';
import 'timeline_labels.dart';
import 'timeline_painter.dart';

const loopAreaHeight = 17.0;

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

    if (project.sequence.playbackStartPosition != targetTime) {
      project.sequence.playbackStartPosition = targetTime;
    }

    if (_lastPlayheadPositionSet != targetTime) {
      final asDouble = targetTime.toDouble();
      if (project.engine.isRunning) {
        project.engine.sequencerApi.jumpPlayheadTo(asDouble);
      }
      _lastPlayheadPositionSet = asDouble;
    }
  }

  void handlePointerDown(PointerEvent event) {
    final arrangement = _arrangement;
    final pattern = _pattern;

    final sequenceId = arrangement?.id ?? pattern?.id;
    if (sequenceId == null) {
      // If there is no arrangement or pattern, we can't handle the pointer down
      return;
    }

    final project = Provider.of<ProjectModel>(context, listen: false);
    if (project.sequence.activeTransportSequenceID != sequenceId) {
      project.sequence.activeTransportSequenceID = sequenceId;
    }

    final deltaSinceLastMouseDown = _lastMouseDownTime == null
        ? Duration(days: 1)
        : DateTime.now().difference(_lastMouseDownTime!);
    final isDoubleClick =
        deltaSinceLastMouseDown.inMilliseconds < 500 &&
        event.buttons & kPrimaryButton != 0;
    _lastMouseDownTime = DateTime.now();

    final isPlayheadMove =
        event.buttons & kPrimaryButton != 0 &&
        event.localPosition.dy > loopAreaHeight;

    final isLoopHandleMove =
        (event.buttons & kPrimaryButton != 0 &&
        !isDoubleClick &&
        (_loopStartPressed || _loopEndPressed));

    final isLoopCreate =
        (isDoubleClick ||
            (event.buttons & kSecondaryButton != 0) ||
            (event.buttons & kPrimaryButton != 0 &&
                HardwareKeyboard.instance.isControlPressed)) &&
        event.localPosition.dy <= loopAreaHeight;

    if (isPlayheadMove) {
      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      _setPlayheadPosition(
        time,
        HardwareKeyboard.instance.isAltPressed,
        pattern: pattern,
      );

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

      if (HardwareKeyboard.instance.isAltPressed) {
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

    if (_playheadMoveActive) {
      var time = pixelsToTime(
        timeViewStart: widget.timeViewStartAnimation.value,
        timeViewEnd: widget.timeViewEndAnimation.value,
        viewPixelWidth: _lastTimelineSize.width,
        pixelOffsetFromLeft: event.localPosition.dx,
      );

      if (time < 0) time = 0;

      _setPlayheadPosition(
        time,
        HardwareKeyboard.instance.isAltPressed,
        pattern: pattern,
      );
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

      if (!HardwareKeyboard.instance.isAltPressed && time > 0) {
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

      if (!HardwareKeyboard.instance.isAltPressed) {
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
              handleScroll(event.scrollDelta.dy * 1.5, event.localPosition.dx);
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
                  color: const Color(0xFF3B3B3B),
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
                    return LoopIndicator(
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

                // Playhead positioner for the playback start position
                VisualizationBuilder.string(
                  config: VisualizationSubscriptionConfig.latest(
                    'playhead_sequence_id',
                  ),
                  builder: (context, activeSequenceIdFromEngine) {
                    return Observer(
                      builder: (context) {
                        final activeSequenceIdOverride =
                            project.engineState != EngineState.running
                            ? project.sequence.activeTransportSequenceID
                            : null;

                        final activeSequenceId =
                            activeSequenceIdOverride ??
                            activeSequenceIdFromEngine;

                        return Visibility(
                          visible:
                              activeSequenceId != null &&
                              (widget.patternID == activeSequenceId ||
                                  widget.arrangementID == activeSequenceId),
                          child: PlayheadPositioner(
                            isStartMarker: true,
                            playheadTimeOverride: project
                                .sequence
                                .playbackStartPosition
                                .toDouble(),
                            timeViewAnimationController:
                                widget.timeViewAnimationController,
                            timeViewStartAnimation:
                                widget.timeViewStartAnimation,
                            timeViewEndAnimation: widget.timeViewEndAnimation,
                            timelineSize: constraints.biggest,
                          ),
                        );
                      },
                    );
                  },
                ),

                // Playhead positioner for the actual playhead
                VisualizationBuilder.string(
                  // This pulls the latest visualization value for the active
                  // sequence ID.
                  //
                  // The engine tells us what sequence it is currently playing.
                  // We could pull this from the local data model, but we need
                  // to pull it from the engine. This is because updates take
                  // some time to propagate to the engine and come back, and so
                  // if we pull one value from the data model (active sequence
                  // ID) and one from the engine (playhead position), we can get
                  // a desync between the two which is noticeable.
                  //
                  // By pulling the active sequence ID from the engine, we
                  // ensure that the playhead position value is always linked to
                  // whatever sequence is active in the engine, and we don't get
                  // a desync.
                  //
                  // Note that the round-trip delay here may be quick enough,
                  // but the worst-case will be around one audio block which may
                  // last even a few frames, depending on the current audio
                  // configuration.
                  config: VisualizationSubscriptionConfig.latest(
                    'playhead_sequence_id',
                  ),
                  builder: (context, activeSequenceIdFromEngine) {
                    return Observer(
                      builder: (context) {
                        final activeSequenceIdOverride =
                            project.engineState != EngineState.running
                            ? project.sequence.activeTransportSequenceID
                            : null;

                        final activeSequenceId =
                            activeSequenceIdOverride ??
                            activeSequenceIdFromEngine;

                        return Visibility(
                          visible:
                              activeSequenceId != null &&
                              (widget.patternID == activeSequenceId ||
                                  widget.arrangementID == activeSequenceId),
                          child: PlayheadPositioner(
                            playheadTimeOverride:
                                project.engineState == EngineState.running
                                ? null
                                : project.sequence.playbackStartPosition
                                      .toDouble(),
                            timeViewAnimationController:
                                widget.timeViewAnimationController,
                            timeViewStartAnimation:
                                widget.timeViewStartAnimation,
                            timeViewEndAnimation: widget.timeViewEndAnimation,
                            timelineSize: constraints.biggest,
                          ),
                        );
                      },
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
