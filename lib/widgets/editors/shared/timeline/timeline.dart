/*
  Copyright (C) 2021 - 2026 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/basic/visualization_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'controller/timeline_controller.dart';
import 'controller/state_machine/timeline_state_machine.dart'
    show TimelineLoopHandle;
import '../helpers/time_helpers.dart';
import '../helpers/types.dart';
import 'loop_indicator.dart';
import 'playhead_handle.dart';
import 'timeline_labels.dart';
import 'timeline_painter.dart';
export 'timeline_constants.dart';

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
  Size? _lastTimelineSize;
  TimelineController? _controller;
  KeyboardModifiers? _keyboardModifiers;
  (int pointerId, TimelineLoopHandle handle)? _nextPointerDownHandlePress;

  void _handleKeyboardModifiersChanged() {
    final keyboardModifiers = _keyboardModifiers;
    final controller = _controller;
    if (keyboardModifiers == null || controller == null) {
      return;
    }

    controller.syncModifierState(
      ctrlPressed: keyboardModifiers.ctrl,
      altPressed: keyboardModifiers.alt,
      shiftPressed: keyboardModifiers.shift,
    );
  }

  void _syncRenderedViewMetrics() {
    if (!mounted) {
      return;
    }

    final controller = _controller;
    final timelineSize = _lastTimelineSize;
    if (controller == null || timelineSize == null) {
      return;
    }

    controller.onViewSizeChanged(timelineSize);
    controller.onRenderedTimeViewChanged(
      timeViewStart: widget.timeViewStartAnimation.value,
      timeViewEnd: widget.timeViewEndAnimation.value,
    );
  }

  TimelineController get _requiredController {
    final controller = _controller;
    if (controller == null) {
      throw StateError('TimelineController was not initialized.');
    }

    return controller;
  }

  void _markNextPointerDownAsLoopHandlePress({
    required int pointerId,
    required TimelineLoopHandle handle,
  }) {
    _nextPointerDownHandlePress = (pointerId, handle);
  }

  TimelineLoopHandle? _consumePressedLoopHandleForPointer(int pointerId) {
    final nextPointerDownHandlePress = _nextPointerDownHandlePress;
    if (nextPointerDownHandlePress?.$1 != pointerId) {
      return null;
    }

    _nextPointerDownHandlePress = null;
    return nextPointerDownHandlePress?.$2;
  }

  void _clearNextPointerDownHandlePressForPointer(int pointerId) {
    if (_nextPointerDownHandlePress?.$1 == pointerId) {
      _nextPointerDownHandlePress = null;
    }
  }

  TimelineController _createController() {
    return TimelineController(
      project: Provider.of<ProjectModel>(context, listen: false),
      arrangementID: widget.arrangementID,
      patternID: widget.patternID,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.timeViewAnimationController.addListener(_syncRenderedViewMetrics);
  }

  /// Recreates the controller if needed.
  ///
  /// Unlike most other high-level editor components, the timeline can have
  /// multiple instances live at once, and the context for each instance is
  /// controlled at the widget level by the parent. This allows each editor to
  /// say, "I want a timeline with these parameters", and the timeline does not
  /// have to interface with each editor's view model or controller in order to
  /// behave correctly.
  ///
  /// This unique setup gives way to a unique architecture here. Unlike the
  /// editors, which have project-wide ownership of view models and controllers
  /// in the service registry, the controller for the timeline (and possibly
  /// view model in the future) is owned by the timeline widget.
  ///
  /// To help keep things clean, the controller is rebuilt any time the incoming
  /// parameters (pattern ID / arrangement ID) change. This allows us to rebuild
  /// the interaction state machine, along with anything else necessary that
  /// might need to be rebuilt.
  void _syncControllerLifecycle({bool forceRecreate = false}) {
    final existingController = _controller;

    if (!forceRecreate && existingController != null) {
      final doesControllerTargetMatchWidget =
          existingController.arrangementID == widget.arrangementID &&
          existingController.patternID == widget.patternID;

      if (doesControllerTargetMatchWidget) {
        return;
      }
    }

    existingController?.dispose();
    _controller = _createController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllerLifecycle();

    _keyboardModifiers ??= Provider.of<KeyboardModifiers>(
      context,
      listen: false,
    )..addListener(_handleKeyboardModifiersChanged);

    _handleKeyboardModifiersChanged();
    _syncRenderedViewMetrics();
  }

  @override
  void didUpdateWidget(covariant Timeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(
      oldWidget.timeViewAnimationController,
      widget.timeViewAnimationController,
    )) {
      oldWidget.timeViewAnimationController.removeListener(
        _syncRenderedViewMetrics,
      );
      widget.timeViewAnimationController.addListener(_syncRenderedViewMetrics);
    }

    final didTargetChange =
        oldWidget.arrangementID != widget.arrangementID ||
        oldWidget.patternID != widget.patternID;
    if (didTargetChange) {
      _syncControllerLifecycle(forceRecreate: true);
    }

    _handleKeyboardModifiersChanged();
    _syncRenderedViewMetrics();
  }

  void handlePointerDown(PointerDownEvent event) {
    _requiredController.pointerDown(
      event,
      pressedLoopHandle: _consumePressedLoopHandleForPointer(event.pointer),
    );
  }

  void handlePointerMove(PointerMoveEvent event) {
    final controller = _requiredController;
    controller.pointerMove(event);
  }

  void handlePointerUp(PointerEvent event) {
    final controller = _requiredController;
    _clearNextPointerDownHandlePressForPointer(event.pointer);
    if (event is PointerCancelEvent) {
      controller.pointerCancel(event);
    } else {
      controller.pointerUp(event);
    }
  }

  @override
  void dispose() {
    widget.timeViewAnimationController.removeListener(_syncRenderedViewMetrics);
    _keyboardModifiers?.removeListener(_handleKeyboardModifiersChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      _requiredController.sequenceId ==
          (widget.arrangementID ?? widget.patternID),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastTimelineSize = constraints.biggest;

        final timeView = context.watch<TimeRange>();
        final project = Provider.of<ProjectModel>(context);
        final controller = _requiredController;
        _syncRenderedViewMetrics();

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
            handleScroll(-event.panDelta.dy * 0.7, event.localPosition.dx);
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              handleScroll(event.scrollDelta.dy * 1.5, event.localPosition.dx);
            }
          },
          onPointerDown: handlePointerDown,
          onPointerMove: handlePointerMove,
          onPointerUp: handlePointerUp,
          onPointerCancel: handlePointerUp,
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
                                timeSignatureChanges: controller
                                    .timeSignatureChanges(),
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
                    final timelineLabels = controller
                        .timeSignatureChanges()
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
                        .toList();

                    return AnimatedBuilder(
                      animation: widget.timeViewAnimationController,
                      builder: (context, child) {
                        return Observer(
                          builder: (context) {
                            return CustomMultiChildLayout(
                              delegate: TimeSignatureLabelLayoutDelegate(
                                timeSignatureChanges: controller
                                    .timeSignatureChanges(),
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
                    final loopPoints = controller.loopPoints();
                    return LoopIndicator(
                      timeViewAnimationController:
                          widget.timeViewAnimationController,
                      timeViewStartAnimation: widget.timeViewStartAnimation,
                      timeViewEndAnimation: widget.timeViewEndAnimation,
                      timelineSize: constraints.biggest,
                      loopStart: loopPoints?.start,
                      loopEnd: loopPoints?.end,
                      onLoopStartPressed: (pointerId) {
                        _markNextPointerDownAsLoopHandlePress(
                          pointerId: pointerId,
                          handle: TimelineLoopHandle.start,
                        );
                      },
                      onLoopEndPressed: (pointerId) {
                        _markNextPointerDownAsLoopHandlePress(
                          pointerId: pointerId,
                          handle: TimelineLoopHandle.end,
                        );
                      },
                    );
                  },
                ),

                // Playhead positioner for the playback start position
                VisualizationBuilder.int(
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
                VisualizationBuilder.int(
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
