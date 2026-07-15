/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'dart:async';

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/editors/arranger/event_listener.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/rendering/content_renderer.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_headers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/playhead_line.dart';
import 'package:anthem/widgets/editors/shared/time_range_animation.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline_notification_handler.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:anthem/widgets/basic/lazy_follower.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart';

import 'widgets/grid.dart';
import 'view_model.dart';

const _timelineHeight = 38.0;
const _scrollbarShortSideLength = 17.0;
const _trackHeaderWidth = TrackLayout.defaultHeaderWidth;

class Arranger extends StatefulWidget {
  const Arranger({super.key});

  @override
  State<Arranger> createState() => _ArrangerState();
}

class _ArrangerState extends State<Arranger> {
  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final viewModel = serviceRegistry.arrangerViewModel;
    final controller = serviceRegistry.arrangerController;

    return MultiProvider(
      providers: [
        Provider.value(value: viewModel),
        Provider.value(value: controller),
      ],
      child: ArrangerTimeRangeProvider(
        child: ShortcutConsumer(
          id: 'arranger',
          shortcutHandler: controller.onShortcut,
          rawKeyHandler: controller.onRawKeyEvent,
          child: Container(
            color: AnthemTheme.panel.background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Observer(
                  builder: (context) {
                    final editorHeight =
                        constraints.maxHeight -
                        _timelineHeight -
                        _scrollbarShortSideLength;
                    viewModel.refreshTrackLayout(editorHeight);

                    // As of writing, the main purpose of this call is to allow
                    // the state machine to react to certain edge cases. For
                    // example, when two-finger scrolling on a trackpad, the
                    // mouse cursor stays still, and so does not emit hover
                    // events. However, we still want to update the editor
                    // cursor position, and this call enables part of that.
                    controller.onTrackLayoutChanged();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: _ArrangerContent()),
                        SizedBox(
                          width: _scrollbarShortSideLength,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: _timelineHeight,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: AnthemTheme.panel.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: AnthemTheme.panel.border,
                                        width: 1,
                                      ),
                                      top: BorderSide(
                                        color: AnthemTheme.panel.border,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: _VerticalScrollbar(),
                                ),
                              ),
                              SizedBox(height: _scrollbarShortSideLength - 1),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalScrollbar extends StatelessObserverWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

    final timeRangeViewport = viewModel.timeRangeViewport;
    final contentBounds = timeRangeViewport.resolveContentBounds(project);

    return Container(
      height: _scrollbarShortSideLength,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AnthemTheme.panel.border, width: 1),
        ),
        color: AnthemTheme.panel.background,
      ),
      child: ScrollbarRenderer(
        scrollRegionStart: 0,
        scrollRegionEnd: contentBounds.end,
        handleStart: timeRangeViewport.target.start,
        handleEnd: timeRangeViewport.target.end,
        canScrollPastEnd: true,
        disableAtFullSize: false,
        onChange: (event) {
          timeRangeViewport.setFromScrollbar(
            start: event.handleStart,
            end: event.handleEnd,
          );
        },
      ),
    );
  }
}

class _VerticalScrollbar extends StatelessObserverWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return ScrollbarRenderer(
      scrollRegionStart: 0,
      scrollRegionEnd: viewModel.scrollAreaHeight,
      handleStart: viewModel.verticalScrollPosition,
      handleEnd: viewModel.verticalScrollPosition + viewModel.editorHeight,
      onChange: (event) {
        viewModel.verticalScrollPosition = event.handleStart;
      },
      disableAtFullSize: true,
    );
  }
}

/// Uses an observer to grab the [TimeRange] from the view model and provide it
/// to the tree. Using a separate widget for this means we can tell the tree
/// about updates to the [TimeRange] without re-rendering [Arranger].
///
/// We provide the [TimeRange] to the tree because some widgets, such as
/// [Timeline], are shared between editors, and they need to access the
/// [TimeRange] without knowing which editor they're associated with.
class ArrangerTimeRangeProvider extends StatelessObserverWidget {
  final Widget? child;

  const ArrangerTimeRangeProvider({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return Provider.value(value: viewModel.timeRange, child: child);
  }
}

// Actual content view of the arranger (timeline + clips + etc)
class _ArrangerContent extends StatefulWidget {
  const _ArrangerContent();

  @override
  State<_ArrangerContent> createState() => _ArrangerContentState();
}

class _ArrangerContentState extends State<_ArrangerContent>
    with TickerProviderStateMixin {
  LazyFollowAnimationHelper? verticalScrollPositionAnimationHelper;

  mobx.ReactionDisposer? animationTweenUpdaterDisposer;

  StreamSubscription<void>? baseTrackHeightChangedSub;

  ArrangerController? _renderedViewTransformController;
  double? _renderedTimeViewStart;
  double? _renderedTimeViewEnd;
  double? _renderedVerticalScrollPosition;
  double? _lastSyncedTimeViewStart;
  double? _lastSyncedTimeViewEnd;
  double? _lastSyncedVerticalScrollPosition;
  double? _lastCanvasWidth;

  void _handleRenderedTimeRangeChanged({
    required double timeRangeStart,
    required double timeRangeEnd,
  }) {
    _renderedTimeViewStart = timeRangeStart;
    _renderedTimeViewEnd = timeRangeEnd;
    _syncRenderedViewTransform();
  }

  void _handleRenderedVerticalScrollPositionChanged() {
    final verticalHelper = verticalScrollPositionAnimationHelper;
    if (verticalHelper == null) {
      return;
    }

    final [verticalScrollPositionAnimItem] = verticalHelper.items;
    _renderedVerticalScrollPosition =
        verticalScrollPositionAnimItem.animation.value;
    _syncRenderedViewTransform();
  }

  void _syncRenderedViewTransform() {
    if (!mounted) {
      return;
    }

    final controller = _renderedViewTransformController;
    final timeViewStart = _renderedTimeViewStart;
    final timeViewEnd = _renderedTimeViewEnd;
    final verticalScrollPosition = _renderedVerticalScrollPosition;
    if (controller == null ||
        timeViewStart == null ||
        timeViewEnd == null ||
        verticalScrollPosition == null) {
      return;
    }

    if (_lastSyncedTimeViewStart == timeViewStart &&
        _lastSyncedTimeViewEnd == timeViewEnd &&
        _lastSyncedVerticalScrollPosition == verticalScrollPosition) {
      return;
    }

    _lastSyncedTimeViewStart = timeViewStart;
    _lastSyncedTimeViewEnd = timeViewEnd;
    _lastSyncedVerticalScrollPosition = verticalScrollPosition;

    controller.onRenderedViewTransformChanged(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      verticalScrollPosition: verticalScrollPosition,
    );
  }

  void _handleCanvasResize({
    required ArrangerViewModel viewModel,
    required ProjectModel project,
    required double width,
  }) {
    if (!width.isFinite || width <= 0) {
      return;
    }

    final previousWidth = _lastCanvasWidth;
    _lastCanvasWidth = width;
    if (previousWidth == null || previousWidth <= 0 || previousWidth == width) {
      return;
    }

    viewModel.timeRangeViewport.resizeViewportPreservingScale(
      oldViewportWidth: previousWidth,
      newViewportWidth: width,
      project: project,
    );
  }

  void _detachRenderedViewTransformListeners() {
    final verticalHelper = verticalScrollPositionAnimationHelper;
    if (verticalHelper != null) {
      verticalHelper.animationController.removeListener(
        _handleRenderedVerticalScrollPositionChanged,
      );
    }
  }

  void _attachRenderedViewTransformListeners(ArrangerController controller) {
    if (identical(_renderedViewTransformController, controller)) {
      return;
    }

    _detachRenderedViewTransformListeners();

    _renderedViewTransformController = controller;
    _lastSyncedTimeViewStart = null;
    _lastSyncedTimeViewEnd = null;
    _lastSyncedVerticalScrollPosition = null;

    verticalScrollPositionAnimationHelper!.animationController.addListener(
      _handleRenderedVerticalScrollPositionChanged,
    );

    _handleRenderedVerticalScrollPositionChanged();
    _syncRenderedViewTransform();
  }

  @override
  void dispose() {
    _detachRenderedViewTransformListeners();
    verticalScrollPositionAnimationHelper?.dispose();
    baseTrackHeightChangedSub?.cancel();
    animationTweenUpdaterDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final controller = Provider.of<ArrangerController>(context);

    final project = Provider.of<ProjectModel>(context);

    verticalScrollPositionAnimationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      animateOnFirstUpdate: false,
      items: [
        LazyFollowItem(
          initialValue: 0,
          getTarget: () => viewModel.verticalScrollPosition,
        ),
      ],
    );

    verticalScrollPositionAnimationHelper!.update();

    final [verticalScrollPositionAnimItem] =
        verticalScrollPositionAnimationHelper!.items;

    _attachRenderedViewTransformListeners(controller);
    _handleRenderedVerticalScrollPositionChanged();

    // Snap vertical scroll position when base track height is changed
    baseTrackHeightChangedSub ??= controller.onBaseTrackHeightChanged.stream
        .listen((event) {
          final animHelper = verticalScrollPositionAnimationHelper!;
          animHelper.items.first.snapTo(viewModel.verticalScrollPosition);
        });

    // Updates the animations whenever the vertical scroll position changes.
    animationTweenUpdaterDisposer ??= mobx.autorun((p0) {
      viewModel.verticalScrollPosition;

      setState(() {});
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _handleCanvasResize(
          viewModel: viewModel,
          project: project,
          width: constraints.maxWidth - _trackHeaderWidth,
        );

        return Observer(
          builder: (context) {
            return TimeRangeAnimationBuilder(
              viewport: viewModel.timeRangeViewport,
              onRenderedTimeRangeChanged: _handleRenderedTimeRangeChanged,
              builder: (context, timeRangeAnimation) {
                return _buildContentWithTimeRangeAnimation(
                  context,
                  project,
                  timeRangeAnimation,
                  verticalScrollPositionAnimItem.animation,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContentWithTimeRangeAnimation(
    BuildContext context,
    ProjectModel project,
    TimeRangeAnimation timeRangeAnimation,
    Animation<double> verticalScrollPositionAnimation,
  ) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            // +1 for bottom border drawn by timeline
            height: _timelineHeight + 1,
            child: Row(
              children: [
                Container(
                  width: _trackHeaderWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AnthemTheme.panel.border),
                    ),
                  ),
                ),
                Expanded(
                  child: TimelineNotificationHandler(
                    timelineKind: TimelineKind.arrangement,
                    child: Timeline.arrangement(
                      timeRangeAnimation: timeRangeAnimation,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _trackHeaderWidth,
                  child: AnimatedBuilder(
                    animation: verticalScrollPositionAnimationHelper!
                        .animationController,
                    builder: (context, child) {
                      return TrackHeaders(
                        verticalScrollPosition:
                            verticalScrollPositionAnimation.value,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ArrangerCanvas(
                          timeRangeAnimation: timeRangeAnimation,
                          verticalScrollPositionAnimation:
                              verticalScrollPositionAnimation,
                          verticalScrollPositionAnimationController:
                              verticalScrollPositionAnimationHelper!
                                  .animationController,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AnthemTheme.panel.border, width: 1),
                  ),
                ),
                width: _trackHeaderWidth,
                height: _scrollbarShortSideLength,
              ),
              Expanded(child: _HorizontalScrollbar()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders the actual clip render area. This includes the time grid and any
/// clips that are in the active arrangement.
class _ArrangerCanvas extends StatelessWidget {
  final TimeRangeAnimation timeRangeAnimation;

  final Animation<double> verticalScrollPositionAnimation;
  final AnimationController verticalScrollPositionAnimationController;

  const _ArrangerCanvas({
    required this.timeRangeAnimation,
    required this.verticalScrollPositionAnimation,
    required this.verticalScrollPositionAnimationController,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final renderedViewRepaint = Listenable.merge([
      timeRangeAnimation.controller,
      verticalScrollPositionAnimationController,
      viewModel.trackLayout.layoutRevision,
    ]);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: AnthemTheme.grid.backgroundLight),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final grid = Observer(
            builder: (context) {
              return Positioned.fill(
                child: CustomPaint(
                  painter: ArrangerBackgroundPainter(
                    repaint: renderedViewRepaint,
                    activeArrangement: project.sequence.arrangement,
                    project: project,
                    verticalScrollPositionAnimation:
                        verticalScrollPositionAnimation,
                    timeRangeAnimation: timeRangeAnimation,
                  ),
                ),
              );
            },
          );

          final clipsContainer = Observer(
            builder: (context) {
              return Positioned.fill(
                child: ArrangerContentRenderer(
                  repaint: renderedViewRepaint,
                  timeRangeAnimation: timeRangeAnimation,
                  verticalScrollPositionAnimation:
                      verticalScrollPositionAnimation,
                  viewModel: viewModel,
                ),
              );
            },
          );

          final selectionBox = Observer(
            builder: (context) {
              if (viewModel.selectionBox == null) {
                return const SizedBox();
              }

              final selectionBox = viewModel.selectionBox!;

              final borderColor = const HSLColor.fromAHSL(
                1,
                166,
                0.6,
                0.35,
              ).toColor();
              final backgroundColor = borderColor.withAlpha(100);

              return Positioned(
                left: selectionBox.left,
                top: selectionBox.top,
                child: Container(
                  width: selectionBox.width,
                  height: selectionBox.height,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border.all(color: borderColor),
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              );
            },
          );

          final playhead = Observer(
            builder: (context) {
              return Positioned.fill(
                child: PlayheadLine(
                  timeRangeAnimation: timeRangeAnimation,
                  isVisible: true,
                  editorActiveSequenceId: project.sequence.arrangement.id,
                ),
              );
            },
          );

          return ArrangerEventListener(
            child: Stack(
              children: [grid, clipsContainer, selectionBox, playhead],
            ),
          );
        },
      ),
    );
  }
}
