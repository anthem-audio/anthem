/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/editors/arranger/content_renderer.dart';
import 'package:anthem/widgets/editors/arranger/event_listener.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/widgets/pattern_picker.dart';
import 'package:anthem/widgets/editors/arranger/widgets/track_header.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/playhead_line.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/widgets/util/lazy_follower.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import 'widgets/grid.dart';
import 'view_model.dart';
import 'helpers.dart';

const _timelineHeight = 38.0;
const _scrollbarShortSideLength = 17.0;

class Arranger extends StatefulWidget {
  const Arranger({super.key});

  @override
  State<Arranger> createState() => _ArrangerState();
}

class _ArrangerState extends State<Arranger> {
  double x = 0;
  double y = 0;

  ArrangerViewModel? viewModel;

  ArrangerController? controller;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    if (this.viewModel == null) {
      this.viewModel = ArrangerViewModel(
        project: project,
        baseTrackHeight: 53,
        timeView: TimeRange(0, 3072),
      );
      ServiceRegistry.forProject(project.id).register(this.viewModel!);
    }

    if (this.controller == null) {
      this.controller = ArrangerController(
        viewModel: this.viewModel!,
        project: project,
      );
      ServiceRegistry.forProject(project.id).register(this.controller!);
    }

    final viewModel = this.viewModel!;
    final controller = this.controller!;

    return MultiProvider(
      providers: [
        Provider.value(value: viewModel),
        Provider.value(value: controller),
      ],
      child: ArrangerTimeViewProvider(
        child: ShortcutConsumer(
          id: 'arranger',
          shortcutHandler: controller.onShortcut,
          child: Container(
            color: AnthemTheme.panel.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(),
                Container(height: 1, color: AnthemTheme.panel.border),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Observer(
                        builder: (context) {
                          final editorHeight =
                              constraints.maxHeight -
                              _timelineHeight -
                              _scrollbarShortSideLength;
                          viewModel.editorHeight = editorHeight;
                          viewModel.verticalScrollPosition = viewModel
                              .verticalScrollPosition
                              .clamp(0.0, viewModel.maxVerticalScrollPosition);

                          viewModel.trackPositionCalculator.invalidate(
                            editorHeight,
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(
                                width: 126,
                                child: PatternPicker(),
                              ),
                              Container(
                                width: 1,
                                color: AnthemTheme.panel.border,
                              ),
                              const Expanded(child: _ArrangerContent()),
                              SizedBox(
                                width: _scrollbarShortSideLength,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                    SizedBox(
                                      height: _scrollbarShortSideLength - 1,
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final projectController = Provider.of<ProjectController>(context);
    final project = Provider.of<ProjectModel>(context);

    final menuController = AnthemMenuController();

    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Menu(
              menuDef: MenuDef(
                children: [
                  AnthemMenuItem(
                    disabled: true,
                    text: 'New arrangement',
                    hint: 'Create a new arrangement',
                    onSelected: () {
                      projectController.addArrangement();
                    },
                  ),
                  Separator(),
                  AnthemMenuItem(
                    text: 'Markers',
                    submenu: MenuDef(
                      children: [
                        AnthemMenuItem(
                          text: 'Add time signature change',
                          hint: 'Add a time signature change',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              menuController: menuController,
              child: Button(
                width: 20,
                contentPadding: EdgeInsets.all(2),
                icon: Icons.kebab,
                onPress: () => menuController.open(),
              ),
            ),
            const SizedBox(width: 4),
            Observer(
              builder: (context) {
                return SizedBox(
                  width: 33,
                  child: Dropdown(
                    showNameOnButton: false,
                    allowNoSelection: false,
                    hint: 'Change the active tool',
                    selectedID: EditorTool.values
                        .firstWhere((tool) => tool.name == viewModel.tool.name)
                        .name,
                    items: [
                      DropdownItem(
                        id: EditorTool.pencil.name,
                        name: 'Pencil',
                        hint:
                            'Pencil: left click to add clips, right click to delete',
                        icon: Icons.tools.pencil,
                      ),
                      DropdownItem(
                        id: EditorTool.eraser.name,
                        name: 'Eraser',
                        hint: 'Eraser: left click to delete clips',
                        icon: Icons.tools.erase,
                      ),
                      DropdownItem(
                        id: EditorTool.select.name,
                        name: 'Select',
                        hint: 'Select: left click and drag to select clips',
                        icon: Icons.tools.select,
                      ),
                      DropdownItem(
                        id: EditorTool.cut.name,
                        name: 'Cut',
                        hint: 'Cut: left click and drag to cut clips',
                        icon: Icons.tools.cut,
                      ),
                    ],
                    onChanged: (id) {
                      viewModel.tool = EditorTool.values.firstWhere(
                        (tool) => tool.name == id,
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Observer(
              builder: (context) {
                return Dropdown(
                  hint: 'Change the active arrangement',
                  selectedID: project.sequence.activeArrangementID,
                  horizontalExpand: false,
                  items: project.sequence.arrangementOrder.map<DropdownItem>((
                    id,
                  ) {
                    final name = project.sequence.arrangements[id]!.name;
                    return DropdownItem(
                      id: id.toString(),
                      name: name,
                      hint: name,
                    );
                  }).toList(),
                  onChanged: (selectedID) {
                    projectController.setActiveArrangement(selectedID);
                  },
                );
              },
            ),
            const SizedBox(width: 4),
          ],
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

    final arrangementModel =
        project.sequence.arrangements[project.sequence.activeArrangementID];

    final horizontalScrollRegionEnd =
        arrangementModel?.viewWidth.toDouble() ??
        project.sequence.ticksPerQuarter * 4 * 4;

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
        scrollRegionEnd: horizontalScrollRegionEnd,
        handleStart: viewModel.timeView.start,
        handleEnd: viewModel.timeView.end,
        canScrollPastEnd: true,
        disableAtFullSize: false,
        onChange: (event) {
          viewModel.timeView.start = event.handleStart;
          viewModel.timeView.end = event.handleEnd;
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
class ArrangerTimeViewProvider extends StatelessObserverWidget {
  final Widget? child;

  const ArrangerTimeViewProvider({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return Provider.value(value: viewModel.timeView, child: child);
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
  LazyFollowAnimationHelper? timeViewAnimationHelper;
  LazyFollowAnimationHelper? verticalScrollPositionAnimationHelper;

  mobx.ReactionDisposer? animationTweenUpdaterDisposer;

  StreamSubscription<void>? baseTrackHeightChangedSub;

  @override
  void dispose() {
    timeViewAnimationHelper?.dispose();
    verticalScrollPositionAnimationHelper?.dispose();
    baseTrackHeightChangedSub?.cancel();
    animationTweenUpdaterDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const trackHeaderWidth = 160.0;

    final viewModel = Provider.of<ArrangerViewModel>(context);
    final controller = Provider.of<ArrangerController>(context);

    final project = Provider.of<ProjectModel>(context);

    timeViewAnimationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      items: [
        LazyFollowItem(
          initialValue: 0,
          getTarget: () => viewModel.timeView.start,
        ),
        LazyFollowItem(
          initialValue: 1,
          getTarget: () => viewModel.timeView.end,
        ),
      ],
    );

    timeViewAnimationHelper!.update();

    final [timeViewStartAnimItem, timeViewEndAnimItem] =
        timeViewAnimationHelper!.items;

    verticalScrollPositionAnimationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
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

    // Snap vertical scroll position when base track height is changed
    baseTrackHeightChangedSub ??= controller.onBaseTrackHeightChanged.stream
        .listen((event) {
          final animHelper = verticalScrollPositionAnimationHelper!;
          animHelper.items.first.snapTo(viewModel.verticalScrollPosition);
        });

    // Updates the animations whenever the vertical scroll position changes.
    animationTweenUpdaterDisposer ??= mobx.autorun((p0) {
      viewModel.verticalScrollPosition;
      viewModel.timeView.start;
      viewModel.timeView.end;

      setState(() {});
    });

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
                  width: trackHeaderWidth + 1,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AnthemTheme.panel.border),
                      bottom: BorderSide(color: AnthemTheme.panel.border),
                    ),
                  ),
                ),
                Expanded(
                  child: Observer(
                    builder: (context) {
                      return Timeline.arrangement(
                        timeViewAnimationController:
                            timeViewEndAnimItem.animationController,
                        timeViewStartAnimation: timeViewStartAnimItem.animation,
                        timeViewEndAnimation: timeViewEndAnimItem.animation,
                        arrangementID: project.sequence.activeArrangementID,
                      );
                    },
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
                  width: trackHeaderWidth,
                  child: AnimatedBuilder(
                    animation: verticalScrollPositionAnimationHelper!
                        .animationController,
                    builder: (context, child) {
                      return _TrackHeaders(
                        verticalScrollPosition:
                            verticalScrollPositionAnimItem.animation.value,
                      );
                    },
                  ),
                ),
                Container(width: 1, color: AnthemTheme.panel.border),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ArrangerCanvas(
                          timeViewStartAnimation:
                              timeViewStartAnimItem.animation,
                          timeViewEndAnimation: timeViewEndAnimItem.animation,
                          timeViewAnimationController:
                              timeViewAnimationHelper!.animationController,
                          verticalScrollPositionAnimation:
                              verticalScrollPositionAnimItem.animation,
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
                width: trackHeaderWidth,
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
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final AnimationController timeViewAnimationController;

  final Animation<double> verticalScrollPositionAnimation;
  final AnimationController verticalScrollPositionAnimationController;

  const _ArrangerCanvas({
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timeViewAnimationController,
    required this.verticalScrollPositionAnimation,
    required this.verticalScrollPositionAnimationController,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return _ArrangerCanvasCursor(
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: AnthemTheme.grid.backgroundLight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final grid = Positioned.fill(
              child: AnimatedBuilder(
                animation: verticalScrollPositionAnimationController,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: timeViewAnimationController,
                    builder: (context, child) {
                      return CustomPaintObserver(
                        painterBuilder: () => ArrangerBackgroundPainter(
                          viewModel: viewModel,
                          activeArrangement:
                              project.sequence.arrangements[project
                                  .sequence
                                  .activeArrangementID],
                          project: project,
                          verticalScrollPosition:
                              verticalScrollPositionAnimation.value,
                          timeViewStart: timeViewStartAnimation.value,
                          timeViewEnd: timeViewEndAnimation.value,
                        ),
                      );
                    },
                  );
                },
              ),
            );

            final clipsContainer = Observer(
              builder: (context) {
                Widget clips() {
                  return AnimatedBuilder(
                    animation: verticalScrollPositionAnimationController,
                    builder: (context, child) {
                      return AnimatedBuilder(
                        animation: timeViewAnimationController,
                        builder: (context, child) {
                          return ArrangerContentRenderer(
                            timeViewStart: timeViewStartAnimation.value,
                            timeViewEnd: timeViewEndAnimation.value,
                            verticalScrollPosition:
                                verticalScrollPositionAnimation.value,
                            viewModel: viewModel,
                          );
                        },
                      );
                    },
                  );
                }

                return Positioned.fill(
                  child: project.sequence.activeArrangementID == null
                      ? const SizedBox()
                      : clips(),
                );
              },
            );

            final selectionBox = Observer(
              builder: (context) {
                if (viewModel.selectionBox == null) {
                  return const SizedBox();
                }

                final selectionBox = viewModel.selectionBox!;

                final left = timeToPixels(
                  timeViewStart: viewModel.timeView.start,
                  timeViewEnd: viewModel.timeView.end,
                  viewPixelWidth: constraints.maxWidth,
                  time: selectionBox.left,
                );

                final width = timeToPixels(
                  timeViewStart: viewModel.timeView.start,
                  timeViewEnd: viewModel.timeView.end,
                  viewPixelWidth: constraints.maxWidth,
                  time: viewModel.timeView.start + selectionBox.width,
                );

                final top = viewModel.trackPositionCalculator.getTrackPosition(
                  selectionBox.top.floor(),
                );
                final bottom = viewModel.trackPositionCalculator
                    .getTrackPosition(
                      (selectionBox.top + selectionBox.height).floor(),
                    );

                final borderColor = const HSLColor.fromAHSL(
                  1,
                  166,
                  0.6,
                  0.35,
                ).toColor();
                final backgroundColor = borderColor.withAlpha(100);

                return Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: width,
                    height: bottom - top,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(color: borderColor),
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                );
              },
            );

            final playhead = Positioned.fill(
              child: PlayheadLine(
                timeViewAnimationController: timeViewAnimationController,
                timeViewStartAnimation: timeViewStartAnimation,
                timeViewEndAnimation: timeViewEndAnimation,
                isVisible: true,
                editorActiveSequenceId: project.sequence.activeArrangementID,
              ),
            );

            return ArrangerEventListener(
              child: Stack(
                children: [grid, clipsContainer, selectionBox, playhead],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Determines the current cursor for the arranger canvas.
class _ArrangerCanvasCursor extends StatefulWidget {
  final Widget? child;

  const _ArrangerCanvasCursor({this.child});

  @override
  State<_ArrangerCanvasCursor> createState() => _ArrangerCanvasCursorState();
}

class _ArrangerCanvasCursorState extends State<_ArrangerCanvasCursor> {
  MouseCursor cursor = MouseCursor.defer;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return MouseRegion(
      cursor: cursor,
      onHover: (e) {
        final pos = e.localPosition;

        final contentUnderCursor = viewModel.getContentUnderCursor(pos);
        final newCursor = contentUnderCursor.resizeHandle != null
            ? SystemMouseCursors.resizeLeftRight
            : contentUnderCursor.clip != null
            ? SystemMouseCursors.move
            : MouseCursor.defer;

        if (cursor == newCursor) return;

        setState(() {
          cursor = newCursor;
        });
      },
      child: widget.child,
    );
  }
}

class _TrackHeaders extends StatefulWidget {
  final double verticalScrollPosition;

  const _TrackHeaders({required this.verticalScrollPosition});

  @override
  State<_TrackHeaders> createState() => _TrackHeadersState();
}

class _TrackHeadersState extends State<_TrackHeaders> {
  double startPixelHeight = -1;
  double startModifier = -1;
  double startY = -1;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final editorHeight = constraints.maxHeight;

        return Observer(
          builder: (context) {
            List<Widget> headers = [];
            List<Widget> resizeHandles = [];

            double positionForAddButton = double.nan;
            var lastTrackWasSendTrack = false;
            var lastTrackBottom = 0.0;

            for (final (trackIndex, (trackId, isSendTrack))
                in project.trackOrder
                    .map((t) => (t, false))
                    .followedBy(
                      project.sendTrackOrder.reversed.map((t) => (t, true)),
                    )
                    .indexed) {
              final heightModifier = viewModel.trackHeightModifiers[trackId]!;

              final trackPosition = viewModel.trackPositionCalculator
                  .getTrackPosition(trackIndex);
              final trackHeight = viewModel.trackPositionCalculator
                  .getTrackHeight(trackIndex);

              if (isSendTrack && !lastTrackWasSendTrack) {
                lastTrackWasSendTrack = true;
                positionForAddButton = lastTrackBottom;
              }

              lastTrackBottom = trackPosition + trackHeight;

              if (trackPosition >= editorHeight) {
                break;
              }

              if (trackPosition + trackHeight > 0) {
                headers.add(
                  Positioned(
                    key: Key(trackId),
                    top: trackPosition + (isSendTrack ? 1 : 0),
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: trackHeight - 1,
                      child: TrackHeader(trackID: trackId),
                    ),
                  ),
                );
                headers.add(
                  Positioned(
                    key: Key('$trackId-border'),
                    top: trackPosition + (isSendTrack ? 0 : (trackHeight - 1)),
                    left: 0,
                    right: 0,
                    height: 1,
                    child: Container(color: AnthemTheme.panel.border),
                  ),
                );
                const resizeHandleHeight = 10.0;
                resizeHandles.add(
                  Positioned(
                    key: Key('$trackId-handle'),
                    left: 0,
                    right: 0,
                    top:
                        trackPosition +
                        trackHeight -
                        1 -
                        resizeHandleHeight / 2,
                    child: SizedBox(
                      height: resizeHandleHeight,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: Listener(
                          onPointerDown: (event) {
                            startPixelHeight = trackHeight;
                            startModifier = heightModifier;
                            startY = event.position.dy;
                          },
                          onPointerMove: (event) {
                            final newPixelHeight =
                                (event.position.dy - startY + startPixelHeight)
                                    .clamp(minTrackHeight, maxTrackHeight);
                            final newModifier =
                                newPixelHeight /
                                startPixelHeight *
                                startModifier;
                            viewModel.trackHeightModifiers[trackId] =
                                newModifier;
                          },
                          // Hack: Listener callbacks do nothing unless this is
                          // here
                          child: Container(color: const Color(0x00000000)),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }

            // If we didn't fill the whole area, then we are at the end of the
            // track list, so we can add an "add track" button
            if (!positionForAddButton.isNaN) {
              headers.add(
                Positioned(
                  key: Key('add-track-button'),
                  top: positionForAddButton + 8,
                  left: 16,
                  right: 16,
                  child: Button(
                    icon: Icons.add,
                    hint: [.new('click', 'Add a new track')],
                    onPress: () {
                      final controller = ServiceRegistry.forProject(
                        project.id,
                      ).projectController;
                      controller.addTrack();
                    },
                  ),
                ),
              );
            }

            return ClipRect(child: Stack(children: headers + resizeHandles));
          },
        );
      },
    );
  }
}
