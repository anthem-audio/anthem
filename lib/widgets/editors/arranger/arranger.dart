/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
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
import 'package:anthem/widgets/editors/arranger/widgets/track_header.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import 'widgets/grid.dart';
import 'view_model.dart';
import './widgets/clip_layout_delegate.dart';
import './widgets/clip_sizer.dart';
import 'helpers.dart';
import 'widgets/pattern_picker.dart';

const _timelineHeight = 44.0;

class Arranger extends StatefulWidget {
  const Arranger({Key? key}) : super(key: key);

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
    final projectController = Provider.of<ProjectController>(context);

    viewModel ??= ArrangerViewModel(
      baseTrackHeight: 45,
      trackHeightModifiers: mobx.ObservableMap.of(
        project.song.tracks.nonObservableInner.map(
          (key, value) => MapEntry(key, 1),
        ),
      ),
      timeView: TimeRange(0, 3072),
    );

    controller ??= ArrangerController(
      viewModel: viewModel!,
      project: project,
    );

    ArrangementModel? getModel() =>
        project.song.arrangements[project.song.activeArrangementID];
    double getHorizontalScrollRegionEnd() =>
        getModel()?.width.toDouble() ?? project.song.ticksPerQuarter * 4 * 4;

    final menuController = MenuController();

    return Provider.value(
      value: viewModel!,
      child: Provider.value(
        value: controller!,
        child: ArrangerTimeViewProvider(
          child: ShortcutConsumer(
            id: 'arranger',
            shortcutHandler: controller!.onShortcut,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Theme.panel.main,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 263,
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
                                                text:
                                                    'Add time signature change',
                                                hint:
                                                    'Add a time signature change'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  menuController: menuController,
                                  child: Button(
                                    width: 26,
                                    icon: Icons.kebab,
                                    onPress: () => menuController.open?.call(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Observer(builder: (context) {
                                  return SizedBox(
                                    width: 39,
                                    child: Dropdown(
                                      showNameOnButton: false,
                                      allowNoSelection: false,
                                      hint: 'Change the active tool',
                                      selectedID: EditorTool.values
                                          .firstWhere(
                                            (tool) =>
                                                tool.name ==
                                                viewModel!.tool.name,
                                          )
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
                                          hint:
                                              'Eraser: left click to delete clips',
                                          icon: Icons.tools.erase,
                                        ),
                                        DropdownItem(
                                          id: EditorTool.select.name,
                                          name: 'Select',
                                          hint:
                                              'Select: left click and drag to select clips',
                                          icon: Icons.tools.select,
                                        ),
                                        DropdownItem(
                                          id: EditorTool.cut.name,
                                          name: 'Cut',
                                          hint:
                                              'Cut: left click and drag to cut clips',
                                          icon: Icons.tools.cut,
                                        ),
                                      ],
                                      onChanged: (id) {
                                        viewModel!.tool =
                                            EditorTool.values.firstWhere(
                                          (tool) => tool.name == id,
                                        );
                                      },
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Observer(builder: (context) {
                                    return Dropdown(
                                      hint: 'Change the active arrangement',
                                      selectedID:
                                          project.song.activeArrangementID,
                                      items: project.song.arrangementOrder
                                          .map<DropdownItem>((id) {
                                        final name =
                                            project.song.arrangements[id]!.name;
                                        return DropdownItem(
                                          id: id.toString(),
                                          name: name,
                                          hint: name,
                                        );
                                      }).toList(),
                                      onChanged: (selectedID) {
                                        project.song.activeArrangementID =
                                            selectedID;
                                      },
                                    );
                                  }),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                          Observer(builder: (context) {
                            return Expanded(
                              child: ScrollbarRenderer(
                                scrollRegionStart: 0,
                                scrollRegionEnd: getHorizontalScrollRegionEnd(),
                                handleStart: viewModel!.timeView.start,
                                handleEnd: viewModel!.timeView.end,
                                canScrollPastEnd: true,
                                disableAtFullSize: false,
                                onChange: (event) {
                                  viewModel!.timeView.start = event.handleStart;
                                  viewModel!.timeView.end = event.handleEnd;
                                },
                              ),
                            );
                          }),
                          const SizedBox(width: 4),
                          Observer(builder: (context) {
                            return VerticalScaleControl(
                              min: 0,
                              max: maxTrackHeight,
                              value: viewModel!.baseTrackHeight,
                              onChange: (newHeight) {
                                controller!.setBaseTrackHeight(newHeight);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 15),
                            child: SizedBox(
                              width: 126,
                              child: PatternPicker(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: _ArrangerContent(),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 17,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Observer(builder: (context) {
                                  return ScrollbarRenderer(
                                    scrollRegionStart: 0,
                                    scrollRegionEnd:
                                        viewModel!.scrollAreaHeight,
                                    handleStart:
                                        viewModel!.verticalScrollPosition,
                                    handleEnd:
                                        viewModel!.verticalScrollPosition +
                                            constraints.maxHeight -
                                            _timelineHeight,
                                    onChange: (event) {
                                      viewModel!.verticalScrollPosition =
                                          event.handleStart;
                                    },
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

  const ArrangerTimeViewProvider({Key? key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return Provider.value(value: viewModel.timeView, child: child);
  }
}

// Actual content view of the arranger (timeline + clips + etc)
class _ArrangerContent extends StatefulWidget {
  const _ArrangerContent({Key? key}) : super(key: key);

  @override
  State<_ArrangerContent> createState() => _ArrangerContentState();
}

class _ArrangerContentState extends State<_ArrangerContent>
    with TickerProviderStateMixin {
  // Fields for time view animation

  late final AnimationController _timeViewAnimationController =
      AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
  );

  double _lastTimeViewStart = 0;
  double _lastTimeViewEnd = 1;

  late final Tween<double> _timeViewStartTween =
      Tween<double>(begin: _lastTimeViewStart, end: _lastTimeViewStart);
  late final Tween<double> _timeViewEndTween =
      Tween<double>(begin: _lastTimeViewEnd, end: _lastTimeViewEnd);

  late final Animation<double> _timeViewStartAnimation =
      _timeViewStartTween.animate(
    CurvedAnimation(
      parent: _timeViewAnimationController,
      curve: Curves.easeOutExpo,
    ),
  );
  late final Animation<double> _timeViewEndAnimation =
      _timeViewEndTween.animate(
    CurvedAnimation(
      parent: _timeViewAnimationController,
      curve: Curves.easeOutExpo,
    ),
  );

  // Fields for vertical scroll position animation

  late final AnimationController _verticalScrollPositionAnimationController =
      AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
  );

  double _lastVerticalScrollPosition = 0;

  late final Tween<double> _verticalScrollPositionTween = Tween<double>(
      begin: _lastVerticalScrollPosition, end: _lastVerticalScrollPosition);

  late final Animation<double> _verticalScrollPositionAnimation =
      _verticalScrollPositionTween.animate(
    CurvedAnimation(
      parent: _verticalScrollPositionAnimationController,
      curve: Curves.easeOutExpo,
    ),
  );

  mobx.ReactionDisposer? verticalScrollPosTweenUpdaterSub;

  /// See [PianoRollEventListener] for details on what this is for.
  final clipWidgetEventData = ClipWidgetEventData();

  @override
  void dispose() {
    _timeViewAnimationController.dispose();
    verticalScrollPosTweenUpdaterSub?.call();
    super.dispose();
  }

  bool useNewArrangerRenderer = false;

  @override
  Widget build(BuildContext context) {
    const trackHeaderWidth = 130.0;

    final viewModel = Provider.of<ArrangerViewModel>(context);

    final project = Provider.of<ProjectModel>(context);

    // Updates the vertical scroll position animation whenever the vertical
    // scroll position changes.
    verticalScrollPosTweenUpdaterSub ??= mobx.autorun((p0) {
      viewModel.verticalScrollPosition;
      viewModel.timeView.start;
      viewModel.timeView.end;

      setState(() {});
    });

    // Updates the time view animation if the time view has changed
    if (viewModel.timeView.start != _lastTimeViewStart ||
        viewModel.timeView.end != _lastTimeViewEnd) {
      _timeViewStartTween.begin = _timeViewStartAnimation.value;
      _timeViewEndTween.begin = _timeViewEndAnimation.value;

      _timeViewAnimationController.reset();

      _timeViewStartTween.end = viewModel.timeView.start;
      _timeViewEndTween.end = viewModel.timeView.end;

      _timeViewAnimationController.forward();

      _lastTimeViewStart = viewModel.timeView.start;
      _lastTimeViewEnd = viewModel.timeView.end;
    }

    if (viewModel.verticalScrollPosition != _lastVerticalScrollPosition) {
      _verticalScrollPositionTween.begin =
          _verticalScrollPositionAnimation.value;
      _verticalScrollPositionAnimationController.reset();
      _verticalScrollPositionTween.end = viewModel.verticalScrollPosition;
      _verticalScrollPositionAnimationController.forward();
      _lastVerticalScrollPosition = viewModel.verticalScrollPosition;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.panel.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _timelineHeight,
              child: Row(
                children: [
                  const SizedBox(width: trackHeaderWidth),
                  Container(width: 1, color: Theme.panel.border),
                  Expanded(
                    child: Observer(builder: (context) {
                      return Timeline.arrangement(
                        timeViewAnimationController:
                            _timeViewAnimationController,
                        timeViewStartAnimation: _timeViewStartAnimation,
                        timeViewEndAnimation: _timeViewEndAnimation,
                        arrangementID: project.song.activeArrangementID,
                      );
                    }),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Theme.panel.border),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: trackHeaderWidth,
                    child: AnimatedBuilder(
                      animation: _verticalScrollPositionAnimationController,
                      builder: (context, child) {
                        return _TrackHeaders(
                          verticalScrollPosition:
                              _verticalScrollPositionAnimation.value,
                        );
                      },
                    ),
                  ),
                  Container(width: 1, color: Theme.panel.border),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _ArrangerCanvas(
                            timeViewStartAnimation: _timeViewStartAnimation,
                            timeViewEndAnimation: _timeViewEndAnimation,
                            timeViewAnimationController:
                                _timeViewAnimationController,
                            verticalScrollPositionAnimation:
                                _verticalScrollPositionAnimation,
                            verticalScrollPositionAnimationController:
                                _verticalScrollPositionAnimationController,
                            clipWidgetEventData: clipWidgetEventData,
                            useNewArrangerRenderer: useNewArrangerRenderer,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Button(
                            width: 30,
                            height: 30,
                            toggleState: useNewArrangerRenderer,
                            icon: Icons.anthem,
                            onPress: () {
                              setState(() {
                                useNewArrangerRenderer =
                                    !useNewArrangerRenderer;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  final ClipWidgetEventData clipWidgetEventData;

  final bool useNewArrangerRenderer;

  const _ArrangerCanvas({
    Key? key,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
    required this.timeViewAnimationController,
    required this.verticalScrollPositionAnimation,
    required this.verticalScrollPositionAnimationController,
    required this.clipWidgetEventData,
    this.useNewArrangerRenderer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<ArrangerViewModel>(context);

    return ClipRect(
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
                        activeArrangement: project.song
                            .arrangements[project.song.activeArrangementID],
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

          ArrangementModel? getArrangement() =>
              project.song.arrangements[project.song.activeArrangementID];

          List<Widget> getClipWidgets() =>
              (getArrangement()?.clips.keys ?? []).map<Widget>(
                (id) {
                  return LayoutId(
                    key: Key(id),
                    id: id,
                    child: AnimatedBuilder(
                      animation: timeViewAnimationController,
                      builder: (context, child) {
                        return Observer(builder: (context) {
                          return ClipSizer(
                            clipID: id,
                            arrangementID: project.song.activeArrangementID!,
                            editorWidth: constraints.maxWidth,
                            timeViewStart: timeViewStartAnimation.value,
                            timeViewEnd: timeViewEndAnimation.value,
                            child: Clip(
                              clipID: id,
                              arrangementID: project.song.activeArrangementID!,
                              ticksPerPixel: (timeViewEndAnimation.value -
                                      timeViewStartAnimation.value) /
                                  constraints.maxWidth,
                              selected: viewModel.selectedClips.contains(id),
                              eventData: clipWidgetEventData,
                              pressed: viewModel.pressedClip == id,
                            ),
                          );
                        });
                      },
                    ),
                  );
                },
              ).toList();

          final clipsContainer = Observer(builder: (context) {
            Widget clips() {
              return AnimatedBuilder(
                animation: verticalScrollPositionAnimationController,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: timeViewAnimationController,
                    builder: (context, child) {
                      if (useNewArrangerRenderer) {
                        return ArrangerContentRenderer(
                          timeViewStart: timeViewStartAnimation.value,
                          timeViewEnd: timeViewEndAnimation.value,
                          verticalScrollPosition:
                              verticalScrollPositionAnimation.value,
                          viewModel: viewModel,
                        );
                      }

                      return Observer(builder: (context) {
                        // Subscribe to updates for track heights
                        viewModel.baseTrackHeight;
                        viewModel.trackHeightModifiers.forEach((key, value) {});

                        // Subscribe to updates for clip positions
                        final arrangement = getArrangement()!;
                        for (final clip in arrangement.clips.values) {
                          clip.offset;
                          clip.trackID;
                        }

                        return CustomMultiChildLayout(
                          delegate: ClipLayoutDelegate(
                            baseTrackHeight: viewModel.baseTrackHeight,
                            trackHeightModifiers:
                                viewModel.trackHeightModifiers,
                            timeViewStart: timeViewStartAnimation.value,
                            timeViewEnd: timeViewEndAnimation.value,
                            project: project,
                            trackIDs:
                                project.song.trackOrder.nonObservableInner,
                            clipIDs:
                                getArrangement()?.clips.keys.toList() ?? [],
                            arrangementID: project.song.activeArrangementID!,
                            verticalScrollPosition:
                                verticalScrollPositionAnimation.value,
                          ),
                          children: getClipWidgets(),
                        );
                      });
                    },
                  );
                },
              );
            }

            return Positioned.fill(
              child: project.song.activeArrangementID == null
                  ? const SizedBox()
                  : clips(),
            );
          });

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

              final top = trackIndexToPos(
                baseTrackHeight: viewModel.baseTrackHeight,
                scrollPosition: viewModel.verticalScrollPosition,
                trackHeightModifiers: viewModel.trackHeightModifiers,
                trackOrder: project.song.trackOrder,
                trackIndex: selectionBox.top,
              );

              final bottom = trackIndexToPos(
                baseTrackHeight: viewModel.baseTrackHeight,
                scrollPosition: viewModel.verticalScrollPosition,
                trackHeightModifiers: viewModel.trackHeightModifiers,
                trackOrder: project.song.trackOrder,
                trackIndex: selectionBox.top + selectionBox.height,
              );

              final borderColor =
                  const HSLColor.fromAHSL(1, 166, 0.6, 0.35).toColor();
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

          return ArrangerEventListener(
            eventData: clipWidgetEventData,
            child: Stack(
              children: [grid, clipsContainer, selectionBox],
            ),
          );
        },
      ),
    );
  }
}

class _TrackHeaders extends StatefulWidget {
  final double verticalScrollPosition;

  const _TrackHeaders({
    Key? key,
    required this.verticalScrollPosition,
  }) : super(key: key);

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
        return Observer(builder: (context) {
          List<Widget> headers = [];
          List<Widget> resizeHandles = [];

          var trackPositionPointer = -widget.verticalScrollPosition;

          for (final trackID in project.song.trackOrder) {
            final heightModifier = viewModel.trackHeightModifiers[trackID];

            if (heightModifier == null) continue;

            final trackHeight = getTrackHeight(
              viewModel.baseTrackHeight,
              heightModifier,
            );

            if (trackPositionPointer < constraints.maxHeight &&
                trackPositionPointer + trackHeight > 0) {
              headers.add(
                Positioned(
                  key: Key(trackID),
                  top: trackPositionPointer,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: trackHeight - 1,
                    child: TrackHeader(trackID: trackID),
                  ),
                ),
              );
              const resizeHandleHeight = 10.0;
              resizeHandles.add(
                Positioned(
                  key: Key('$trackID-handle'),
                  left: 0,
                  right: 0,
                  top: trackPositionPointer +
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
                              newPixelHeight / startPixelHeight * startModifier;
                          viewModel.trackHeightModifiers[trackID] = newModifier;
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

            if (trackPositionPointer >= constraints.maxHeight) break;

            trackPositionPointer += trackHeight;
          }

          return ClipRect(child: Stack(children: headers + resizeHandles));
        });
      },
    );
  }
}
