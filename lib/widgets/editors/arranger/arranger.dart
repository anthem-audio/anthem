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

import 'package:anthem/commands/arrangement_commands.dart';
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
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/arranger/track_header.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:anthem/widgets/editors/shared/tool_selector.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart';

import 'arranger_grid.dart';
import 'arranger_view_model.dart';
import 'clip_layout_delegate.dart';
import 'clip_sizer.dart';
import 'helpers.dart';
import 'pattern_picker/pattern_picker.dart';

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
    );

    ArrangementModel? getModel() =>
        project.song.arrangements[project.song.activeArrangementID];
    double getHorizontalScrollRegionEnd() =>
        getModel()?.width.toDouble() ?? project.song.ticksPerQuarter * 4 * 4;

    void setBaseTrackHeight(double trackHeight) {
      final oldClampedTrackHeight =
          viewModel!.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
      final oldVerticalScrollPosition = viewModel!.verticalScrollPosition;
      final clampedTrackHeight =
          trackHeight.clamp(minTrackHeight, maxTrackHeight);

      viewModel!.baseTrackHeight = trackHeight;
      viewModel!.verticalScrollPosition = oldVerticalScrollPosition *
          (clampedTrackHeight / oldClampedTrackHeight);
    }

    return Provider.value(
      value: viewModel!,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TimeView(0, 3072)),
        ],
        builder: (context, widget) {
          final menuController = MenuController();

          final timeView = Provider.of<TimeView>(context);

          return Container(
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
                                      text: "New arrangement",
                                      onSelected: () {
                                        projectController.addArrangement();
                                      },
                                    ),
                                    Separator(),
                                    AnthemMenuItem(
                                      text: "Markers",
                                      submenu: MenuDef(
                                        children: [
                                          AnthemMenuItem(
                                            text: "Add time signature change",
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                menuController: menuController,
                                child: Button(
                                  width: 26,
                                  startIcon: Icons.kebab,
                                  onPress: () => menuController.open?.call(),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Observer(builder: (context) {
                                return ToolSelector(
                                  selectedTool: viewModel!.tool,
                                  setTool: (tool) {
                                    viewModel!.tool = tool;
                                  },
                                );
                              }),
                              const SizedBox(width: 4),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Dropdown(
                                  selectedID: project.song.activeArrangementID,
                                  items: project.song.arrangementOrder
                                      .map<DropdownItem>(
                                        (id) => DropdownItem(
                                          id: id.toString(),
                                          name: project
                                              .song.arrangements[id]!.name,
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (selectedID) {
                                    project.song.activeArrangementID =
                                        selectedID;
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ScrollbarRenderer(
                            scrollRegionStart: 0,
                            scrollRegionEnd: getHorizontalScrollRegionEnd(),
                            handleStart: timeView.start,
                            handleEnd: timeView.end,
                            canScrollPastEnd: true,
                            onChange: (event) {
                              timeView.setStart(event.handleStart);
                              timeView.setEnd(event.handleEnd);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Observer(builder: (context) {
                          return VerticalScaleControl(
                            min: 0,
                            max: maxTrackHeight,
                            value: viewModel!.baseTrackHeight,
                            onChange: (newHeight) {
                              setBaseTrackHeight(newHeight);
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
                                  scrollRegionEnd: viewModel!.scrollAreaHeight,
                                  handleStart:
                                      viewModel!.verticalScrollPosition,
                                  handleEnd: viewModel!.verticalScrollPosition +
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
          );
        },
      ),
    );
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

  @override
  void dispose() {
    _timeViewAnimationController.dispose();
    verticalScrollPosTweenUpdaterSub?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const trackHeaderWidth = 130.0;

    final viewModel = Provider.of<ArrangerViewModel>(context);

    final project = Provider.of<ProjectModel>(context);

    // Updates the vertical scroll position animation whenever the vertical
    // scroll position changes.
    verticalScrollPosTweenUpdaterSub ??= mobx.autorun((p0) {
      viewModel.verticalScrollPosition;

      setState(() {});
    });

    /// Here we access all the track height values. Running this function in
    /// an Observer will tell that Observer to re-render when any of these
    /// values change.
    void subscribeToTrackHeights() {
      viewModel.baseTrackHeight;
      viewModel.trackHeightModifiers.forEach((key, value) {});
    }

    void subscribeToTracks() {
      project.song.tracks.forEach((key, value) {});
      for (var _ in project.song.trackOrder) {}
    }

    void handleMouseDown(Offset offset, Size editorSize, TimeView timeView) {
      if (project.song.activeArrangementID == null ||
          project.song.patternOrder.isEmpty) return;

      final arrangementID = project.song.activeArrangementID!;

      final trackIndex = posToTrackIndex(
        yOffset: offset.dy,
        baseTrackHeight: viewModel.baseTrackHeight,
        trackHeightModifiers: viewModel.trackHeightModifiers,
        trackOrder: project.song.trackOrder,
        scrollPosition: viewModel.verticalScrollPosition,
      );
      if (trackIndex.isInfinite) return;

      final time = pixelsToTime(
        timeViewStart: timeView.start,
        timeViewEnd: timeView.end,
        viewPixelWidth: editorSize.width,
        pixelOffsetFromLeft: offset.dx,
      );

      project.execute(AddClipCommand(
        project: project,
        arrangementID: arrangementID,
        trackID: project.song.trackOrder[trackIndex.floor()],
        patternID: project.song.patterns[project.song.patternOrder[0]]!.id,
        offset: time.floor(),
      ));
    }

    final timeView = context.watch<TimeView>();

    // Updates the time view animation if the time view has changed
    if (timeView.start != _lastTimeViewStart ||
        timeView.end != _lastTimeViewEnd) {
      _timeViewStartTween.begin = _timeViewStartAnimation.value;
      _timeViewEndTween.begin = _timeViewEndAnimation.value;

      _timeViewAnimationController.reset();

      _timeViewStartTween.end = timeView.start;
      _timeViewEndTween.end = timeView.end;

      _timeViewAnimationController.forward();

      _lastTimeViewStart = timeView.start;
      _lastTimeViewEnd = timeView.end;
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
                    child: ClipRect(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final grid = Positioned.fill(
                            child: Observer(builder: (context) {
                              subscribeToTrackHeights();
                              subscribeToTracks();

                              return AnimatedBuilder(
                                animation:
                                    _verticalScrollPositionAnimationController,
                                builder: (context, child) {
                                  return AnimatedBuilder(
                                    animation: _timeViewAnimationController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: ArrangerBackgroundPainter(
                                          baseTrackHeight:
                                              viewModel.baseTrackHeight,
                                          verticalScrollPosition:
                                              _verticalScrollPositionAnimation
                                                  .value,
                                          trackHeightModifiers:
                                              viewModel.trackHeightModifiers,
                                          trackIDs: project.song.trackOrder
                                              .nonObservableInner,
                                          timeViewStart:
                                              _timeViewStartAnimation.value,
                                          timeViewEnd:
                                              _timeViewEndAnimation.value,
                                          ticksPerQuarter:
                                              project.song.ticksPerQuarter,
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }),
                          );

                          ArrangementModel? getArrangement() => project.song
                              .arrangements[project.song.activeArrangementID];

                          List<Widget> getClipWidgets() =>
                              (getArrangement()?.clips.keys ?? []).map<Widget>(
                                (id) {
                                  return LayoutId(
                                    key: Key(id),
                                    id: id,
                                    child: AnimatedBuilder(
                                      animation: _timeViewAnimationController,
                                      builder: (context, child) {
                                        return Observer(builder: (context) {
                                          return ClipSizer(
                                            clipID: id,
                                            arrangementID: project
                                                .song.activeArrangementID!,
                                            editorWidth: constraints.maxWidth,
                                            timeViewStart:
                                                _timeViewStartAnimation.value,
                                            timeViewEnd:
                                                _timeViewEndAnimation.value,
                                            child: Clip(
                                              clipID: id,
                                              arrangementID: project
                                                  .song.activeArrangementID!,
                                              ticksPerPixel:
                                                  (_timeViewEndAnimation.value -
                                                          _timeViewStartAnimation
                                                              .value) /
                                                      constraints.maxWidth,
                                            ),
                                          );
                                        });
                                      },
                                    ),
                                  );
                                },
                              ).toList();

                          final clipsContainer = Observer(builder: (context) {
                            return Positioned.fill(
                              child: project.song.activeArrangementID == null
                                  ? const SizedBox()
                                  : AnimatedBuilder(
                                      animation:
                                          _verticalScrollPositionAnimationController,
                                      builder: (context, child) {
                                        return AnimatedBuilder(
                                          animation:
                                              _timeViewAnimationController,
                                          builder: (context, child) {
                                            return Observer(builder: (context) {
                                              subscribeToTrackHeights();

                                              return CustomMultiChildLayout(
                                                delegate: ClipLayoutDelegate(
                                                  baseTrackHeight:
                                                      viewModel.baseTrackHeight,
                                                  trackHeightModifiers:
                                                      viewModel
                                                          .trackHeightModifiers,
                                                  timeViewStart:
                                                      _timeViewStartAnimation
                                                          .value,
                                                  timeViewEnd:
                                                      _timeViewEndAnimation
                                                          .value,
                                                  project: project,
                                                  trackIDs: project
                                                      .song
                                                      .trackOrder
                                                      .nonObservableInner,
                                                  clipIDs: getArrangement()
                                                          ?.clips
                                                          .keys
                                                          .toList() ??
                                                      [],
                                                  arrangementID: project.song
                                                      .activeArrangementID!,
                                                  verticalScrollPosition:
                                                      _verticalScrollPositionAnimation
                                                          .value,
                                                ),
                                                children: getClipWidgets(),
                                              );
                                            });
                                          },
                                        );
                                      },
                                    ),
                            );
                          });

                          return Listener(
                            onPointerDown: (event) {
                              handleMouseDown(
                                event.localPosition,
                                Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                timeView,
                              );
                            },
                            child: Stack(
                              children: [grid, clipsContainer],
                            ),
                          );
                        },
                      ),
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
            final heightModifier = viewModel.trackHeightModifiers[trackID]!;

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
                  key: Key("$trackID-handle"),
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
