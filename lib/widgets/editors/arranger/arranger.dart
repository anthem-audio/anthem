/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/clip/clip.dart';
import 'package:anthem/widgets/basic/clip/clip_cubit.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/arranger/arranger_cubit.dart';
import 'package:anthem/widgets/editors/arranger/clip_layout_delegate.dart';
import 'package:anthem/widgets/editors/arranger/clip_sizer.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker.dart';
import 'package:anthem/widgets/editors/arranger/pattern_picker/pattern_picker_cubit.dart';
import 'package:anthem/widgets/editors/arranger/track_header.dart';
import 'package:anthem/widgets/editors/arranger/track_header_cubit.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline.dart';
import 'package:anthem/widgets/editors/shared/timeline_cubit.dart';
import 'package:anthem/widgets/editors/shared/tool_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'arranger_grid.dart';
import 'helpers.dart';

const _timelineHeight = 44.0;

class Arranger extends StatefulWidget {
  const Arranger({Key? key}) : super(key: key);

  @override
  State<Arranger> createState() => _ArrangerState();
}

class _ArrangerState extends State<Arranger> {
  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArrangerCubit, ArrangerState>(
      builder: (context, state) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TimeView(0, 3072)),
          ],
          builder: (context, widget) {
            final menuController = MenuController();

            final cubit = BlocProvider.of<ArrangerCubit>(context);
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
                                          cubit.addArrangement();
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
                                ToolSelector(
                                  selectedTool: state.tool,
                                  setTool: (tool) {
                                    cubit.setTool(tool);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Dropdown(
                                    selectedID:
                                        state.activeArrangementID.toString(),
                                    items: state.arrangementIDs
                                        .map<DropdownItem>(
                                          (id) => DropdownItem(
                                            id: id.toString(),
                                            name: state.arrangementNames[id]!,
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (selectedID) {
                                      cubit.setActiveArrangement(selectedID);
                                    },
                                  ),
                                  fit: FlexFit.tight,
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ScrollbarRenderer(
                              scrollRegionStart: 0,
                              scrollRegionEnd:
                                  state.arrangementWidth.toDouble(),
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
                          VerticalScaleControl(
                            min: 0,
                            max: maxTrackHeight,
                            value: state.baseTrackHeight,
                            onChange: (newHeight) {
                              cubit.setBaseTrackHeight(newHeight);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: SizedBox(
                              width: 126,
                              child: BlocProvider<PatternPickerCubit>(
                                create: (context) => PatternPickerCubit(
                                    projectID: state.projectID),
                                child: PatternPicker(),
                              ),
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
                                return ScrollbarRenderer(
                                  scrollRegionStart: 0,
                                  scrollRegionEnd: state.scrollAreaHeight,
                                  handleStart: state.verticalScrollPosition,
                                  handleEnd: state.verticalScrollPosition +
                                      constraints.maxHeight -
                                      _timelineHeight,
                                  onChange: (event) {
                                    cubit.setVerticalScrollPosition(
                                        event.handleStart);
                                  },
                                );
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
        );
      },
    );
  }
}

// Actual content view of the arranger (timeline + clips + etc)
class _ArrangerContent extends StatelessWidget {
  const _ArrangerContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const trackHeaderWidth = 130.0;

    return BlocBuilder<ArrangerCubit, ArrangerState>(
      builder: (context, state) {
        final cubit = BlocProvider.of<ArrangerCubit>(context);

        final timeView = Provider.of<TimeView>(context);

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
                        child: BlocProvider<TimelineCubit>(
                          create: (context) => TimelineCubit(
                            projectID: state.projectID,
                            timelineType: TimelineType.arrangerTimeline,
                          ),
                          child: const Timeline(),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: Theme.panel.border),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        width: trackHeaderWidth,
                        child: _TrackHeaders(),
                      ),
                      Container(width: 1, color: Theme.panel.border),
                      Expanded(
                        child: ClipRect(
                          child: LayoutBuilder(builder: (context, constraints) {
                            final grid = Positioned.fill(
                              child: CustomPaint(
                                painter: ArrangerBackgroundPainter(
                                  baseTrackHeight: state.baseTrackHeight,
                                  verticalScrollPosition:
                                      state.verticalScrollPosition,
                                  trackHeightModifiers:
                                      state.trackHeightModifiers,
                                  trackIDs: state.trackIDs,
                                  timeViewStart: timeView.start,
                                  timeViewEnd: timeView.end,
                                  ticksPerQuarter: state.ticksPerQuarter,
                                ),
                              ),
                            );

                            final clips = Positioned.fill(
                              child: state.activeArrangementID == null
                                  ? const SizedBox()
                                  : CustomMultiChildLayout(
                                      delegate: ClipLayoutDelegate(
                                        baseTrackHeight: state.baseTrackHeight,
                                        trackHeightModifiers:
                                            state.trackHeightModifiers,
                                        timeViewStart: timeView.start,
                                        timeViewEnd: timeView.end,
                                        project: cubit.project,
                                        trackIDs: state.trackIDs,
                                        clipIDs: state.clipIDs,
                                        arrangementID:
                                            state.activeArrangementID!,
                                        verticalScrollPosition:
                                            state.verticalScrollPosition,
                                      ),
                                      children: state.clipIDs.map<Widget>(
                                        (id) {
                                          return LayoutId(
                                            key: Key(id.toString()),
                                            id: id,
                                            child: BlocProvider<ClipCubit>(
                                              create: (context) => ClipCubit(
                                                projectID: state.projectID,
                                                arrangementID:
                                                    state.activeArrangementID!,
                                                clipID: id,
                                              ),
                                              child: ClipSizer(
                                                editorWidth:
                                                    constraints.maxWidth,
                                                timeViewStart: timeView.start,
                                                timeViewEnd: timeView.end,
                                                child: Clip(
                                                  ticksPerPixel:
                                                      timeView.width /
                                                          constraints.maxWidth,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).toList(),
                                    ),
                            );

                            return Listener(
                              onPointerDown: (event) {
                                cubit.handleMouseDown(
                                  event.localPosition,
                                  Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                  timeView,
                                );
                              },
                              child: Stack(
                                children: [grid, clips],
                              ),
                            );
                          }),
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
    );
  }
}

class _TrackHeaders extends StatefulWidget {
  const _TrackHeaders({Key? key}) : super(key: key);

  @override
  State<_TrackHeaders> createState() => _TrackHeadersState();
}

class _TrackHeadersState extends State<_TrackHeaders> {
  double startPixelHeight = -1;
  double startModifier = -1;
  double startY = -1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArrangerCubit, ArrangerState>(
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cubit = Provider.of<ArrangerCubit>(context);

            List<Widget> headers = [];
            List<Widget> resizeHandles = [];

            var trackPositionPointer = -state.verticalScrollPosition;

            for (final trackID in state.trackIDs) {
              final trackIDStr = trackID.toString();

              final heightModifier = state.trackHeightModifiers[trackID]!;

              final trackHeight = getTrackHeight(
                state.baseTrackHeight,
                heightModifier,
              );

              if (trackPositionPointer < constraints.maxHeight &&
                  trackPositionPointer + trackHeight > 0) {
                headers.add(
                  Positioned(
                    key: Key(trackIDStr),
                    top: trackPositionPointer,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: trackHeight - 1,
                      child: BlocProvider<TrackHeaderCubit>(
                        create: (context) {
                          return TrackHeaderCubit(
                            projectID: state.projectID,
                            trackID: trackID,
                          );
                        },
                        child: const TrackHeader(),
                      ),
                    ),
                  ),
                );
                const resizeHandleHeight = 10.0;
                resizeHandles.add(
                  Positioned(
                    key: Key("$trackIDStr-handle"),
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
                            final newModifier = newPixelHeight /
                                startPixelHeight *
                                startModifier;
                            cubit.setHeightModifier(trackID, newModifier);
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
          },
        );
      },
    );
  }
}
