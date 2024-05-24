/*
  Copyright (C) 2021 - 2024 Joshua Wade

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

import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/basic/dropdown.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/editors/piano_roll/content_renderer.dart';
import 'package:anthem/widgets/util/lazy_follower.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import '../shared/helpers/types.dart';
import '../shared/timeline/timeline_notification_handler.dart';
import '../shared/timeline/timeline.dart';
import 'controller/piano_roll_controller.dart';
import 'helpers.dart';
import 'widgets/piano_control.dart';
import 'attribute_editor.dart';
import 'event_listener.dart';
import 'widgets/grid.dart';
import 'view_model.dart';

const noContentBars = 16;

const double minKeyHeight = 6;
const double maxKeyHeight = 40;

const double minKeyValue = 0;
const double maxKeyValue = 128;

// Hack: We need the size of the piano roll's content area at very inconvenient
// times and I don't feel like figuring out how to properly get it where it
// belongs, so here we are. The alternative I can think of is to just calculate
// it where it's needed (we could reasonably infer this from the width of
// _PianoRollHeader, for instance), but then any changes that would affect the
// calculation (e.g. scrollbar width) would need to be reflected in the
// calculation. Instead, I've opted to just store the size on render, since the
// places that need it are currently in callbacks and so will always be fired
// after a render completes.
Size _pianoRollCanvasSize = const Size(0, 0);

class PianoRoll extends StatefulWidget {
  const PianoRoll({super.key});

  @override
  State<PianoRoll> createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  PianoRollController? controller;
  PianoRollViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);

    viewModel ??= PianoRollViewModel(
      keyHeight: 20,
      // Hack: cuts off the top horizontal line. Otherwise the default view looks off
      keyValueAtTop: 63.95,
      timeView: TimeRange(0, 3072),
    );

    controller ??= PianoRollController(
      project: project,
      viewModel: viewModel!,
    );

    return Provider.value(
      value: controller!,
      child: Provider.value(
        value: viewModel!,
        child: PianoRollTimeViewProvider(
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
                  _PianoRollHeader(),
                  const SizedBox(height: 4),
                  const Expanded(
                    child: _PianoRollContent(),
                  ),
                ],
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
/// about updates to the [TimeRange] without re-rendering [PianoRoll].
///
/// We provide the [TimeRange] to the tree because some widgets, such as
/// [Timeline], are shared between editors, and they need to access the
/// [TimeRange] without knowing which editor they're associated with.
class PianoRollTimeViewProvider extends StatelessObserverWidget {
  final Widget? child;

  const PianoRollTimeViewProvider({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return Provider.value(value: viewModel.timeView, child: child);
  }
}

class _PianoRollHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Menu(
            menuDef: MenuDef(
              children: [
                AnthemMenuItem(
                  text: 'Markers',
                  submenu: MenuDef(
                    children: [
                      AnthemMenuItem(
                        text: 'Add time signature change',
                        hint: 'Add a time signature change',
                        onSelected: () {
                          final controller = Provider.of<PianoRollController>(
                              context,
                              listen: false);
                          final timeView =
                              Provider.of<TimeRange>(context, listen: false);

                          controller.addTimeSignatureChange(
                            timeSignature: TimeSignatureModel(3, 4),
                            offset: timeView.start.floor(),
                            pianoRollWidth: _pianoRollCanvasSize.width,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            menuController: menuController,
            child: Button(
              width: 26,
              icon: Icons.kebab,
              onPress: () => menuController.open(),
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
                      (tool) => tool.name == viewModel.tool.name,
                    )
                    .name,
                items: [
                  DropdownItem(
                    id: EditorTool.pencil.name,
                    name: 'Pencil',
                    hint:
                        'Pencil: left click to add notes, right click to delete',
                    icon: Icons.tools.pencil,
                  ),
                  DropdownItem(
                    id: EditorTool.eraser.name,
                    name: 'Eraser',
                    hint: 'Eraser: left click to delete notes',
                    icon: Icons.tools.erase,
                  ),
                  DropdownItem(
                    id: EditorTool.select.name,
                    name: 'Select',
                    hint: 'Select: left click and drag to select notes',
                    icon: Icons.tools.select,
                  ),
                  DropdownItem(
                    id: EditorTool.cut.name,
                    name: 'Cut',
                    hint: 'Cut: left click and drag to cut notes',
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
          }),
        ],
      ),
    );
  }
}

class _PianoRollContent extends StatefulWidget {
  const _PianoRollContent();

  @override
  State<_PianoRollContent> createState() => _PianoRollContentState();
}

class _PianoRollContentState extends State<_PianoRollContent>
    with TickerProviderStateMixin {
  double footerHeight = 61;

  LazyFollowAnimationHelper? timeViewAnimationHelper;
  LazyFollowAnimationHelper? keyValueAtTopAnimationHelper;

  mobx.ReactionDisposer? viewModelReactionDisposer;

  @override
  void dispose() {
    timeViewAnimationHelper?.dispose();
    keyValueAtTopAnimationHelper?.dispose();
    viewModelReactionDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<PianoRollViewModel>(context);

    timeViewAnimationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      items: [
        LazyFollowItem(
          value: 0,
          getTarget: () => viewModel.timeView.start,
        ),
        LazyFollowItem(
          value: 1,
          getTarget: () => viewModel.timeView.end,
        ),
      ],
    );

    timeViewAnimationHelper!.updateOnBuild();

    final [timeViewStartAnimItem, timeViewEndAnimItem] =
        timeViewAnimationHelper!.items;

    keyValueAtTopAnimationHelper ??= LazyFollowAnimationHelper(
      duration: 250,
      vsync: this,
      items: [
        LazyFollowItem(
          value: 0,
          getTarget: () => viewModel.keyValueAtTop,
        ),
      ],
    );

    keyValueAtTopAnimationHelper!.updateOnBuild();

    final [keyValueAtTopAnimItem] = keyValueAtTopAnimationHelper!.items;

    viewModelReactionDisposer ??= mobx.autorun((p0) {
      // Access fields in viewModel. Changes to these fields will rebuild this
      // widget.
      viewModel.keyHeight;
      viewModel.keyValueAtTop;
      viewModel.timeView.start;
      viewModel.timeView.end;

      // Rebuild the widget
      setState(() {});
    });

    // This is a function because observers need to be able to observe this
    // call into the MobX store
    PatternModel? getPattern() =>
        project.song.patterns[project.song.activePatternID];

    final timeline = Observer(builder: (context) {
      final timelineHeight =
          (getPattern()?.hasTimeMarkers ?? false) ? 42.0 : 21.0;
      final pattern = getPattern();

      return SizedBox(
        height: timelineHeight,
        child: Row(
          children: [
            const SizedBox(width: pianoControlWidth),
            Container(color: Theme.panel.border, width: 1),
            Expanded(
              child: TimelineNotificationHandler(
                timelineKind: TimelineKind.pattern,
                patternID: pattern?.id,
                child: Timeline.pattern(
                  timeViewAnimationController:
                      timeViewAnimationHelper!.animationController,
                  timeViewStartAnimation: timeViewStartAnimItem.animation,
                  timeViewEndAnimation: timeViewEndAnimItem.animation,
                  patternID: pattern?.id,
                ),
              ),
            ),
          ],
        ),
      );
    });

    final pianoControl = SizedBox(
      width: pianoControlWidth,
      child: AnimatedBuilder(
        animation: keyValueAtTopAnimationHelper!.animationController,
        builder: (context, child) {
          return PianoControl(
            keyValueAtTop: keyValueAtTopAnimItem.animation.value,
            keyHeight: viewModel.keyHeight,
            setKeyValueAtTop: (value) {
              viewModel.keyValueAtTop = value;
            },
          );
        },
      ),
    );

    final noteRenderArea = Expanded(
      child: LayoutBuilder(builder: (context, constraints) {
        _pianoRollCanvasSize = constraints.biggest;
        return PianoRollEventListener(
          child: _PianoRollCanvasCursor(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PianoRollGrid(
                    timeViewAnimationController:
                        timeViewAnimationHelper!.animationController,
                    timeViewStartAnimation: timeViewStartAnimItem.animation,
                    timeViewEndAnimation: timeViewEndAnimItem.animation,
                    keyValueAtTopAnimationController:
                        keyValueAtTopAnimationHelper!.animationController,
                    keyValueAtTopAnimation: keyValueAtTopAnimItem.animation,
                  ),
                  AnimatedBuilder(
                    animation: timeViewAnimationHelper!.animationController,
                    builder: (context, child) {
                      return AnimatedBuilder(
                        animation: timeViewAnimationHelper!.animationController,
                        builder: (context, child) {
                          return PianoRollContentRenderer(
                            timeViewStart:
                                timeViewStartAnimItem.animation.value,
                            timeViewEnd: timeViewEndAnimItem.animation.value,
                            keyValueAtTop:
                                keyValueAtTopAnimItem.animation.value,
                          );
                        },
                      );
                    },
                  ),
                  Observer(
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

                      final top = keyValueToPixels(
                        keyValueAtTop: viewModel.keyValueAtTop,
                        keyHeight: viewModel.keyHeight,
                        keyValue: selectionBox.bottom,
                      );

                      final height = keyValueToPixels(
                        keyValueAtTop: viewModel.keyValueAtTop,
                        keyHeight: viewModel.keyHeight,
                        keyValue: viewModel.keyValueAtTop - selectionBox.height,
                      );

                      final borderColor =
                          const HSLColor.fromAHSL(1, 166, 0.6, 0.35).toColor();
                      final backgroundColor = borderColor.withAlpha(100);

                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: width,
                          height: height,
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border.all(color: borderColor),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    final controller = Provider.of<PianoRollController>(context);

    return ShortcutConsumer(
      id: 'piano-roll',
      shortcutHandler: controller.onShortcut,
      child: Panel(
        orientation: PanelOrientation.bottom,
        sizeBehavior: PanelSizeBehavior.pixels,
        panelStartSize: 89,
        panelMinSize: 89,
        contentMinSize: 150,
        separatorSize: 6,
        panelContent: PianoRollAttributeEditor(
          timeViewAnimationController:
              timeViewAnimationHelper!.animationController,
          timeViewStartAnimation: timeViewStartAnimItem.animation,
          timeViewEndAnimation: timeViewEndAnimItem.animation,
          viewModel: viewModel,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  const SizedBox(width: pianoControlWidth + 1),
                  Expanded(
                    child: Observer(builder: (context) {
                      return ScrollbarRenderer(
                        scrollRegionStart: 0,
                        scrollRegionEnd: getPattern()?.lastContent.toDouble() ??
                            (project.song.ticksPerQuarter * 4 * noContentBars)
                                .toDouble(),
                        handleStart: viewModel.timeView.start,
                        handleEnd: viewModel.timeView.end,
                        canScrollPastEnd: true,
                        minHandleSize: project.song.ticksPerQuarter * 4,
                        disableAtFullSize: false,
                        onChange: (event) {
                          viewModel.timeView.start = event.handleStart;
                          viewModel.timeView.end = event.handleEnd;
                        },
                      );
                    }),
                  ),
                  const SizedBox(width: 4),
                  VerticalScaleControl(
                    min: minKeyHeight,
                    max: maxKeyHeight,
                    value: viewModel.keyHeight,
                    onChange: (height) {
                      viewModel.keyHeight = height;
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
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.panel.border),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                        child: Column(
                          children: [
                            timeline,
                            Container(color: Theme.panel.border, height: 1),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  pianoControl,
                                  Container(
                                      color: Theme.panel.border, width: 1),
                                  noteRenderArea,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Vertical scrollbar
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 17,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ScrollbarRenderer(
                          scrollRegionStart: minKeyValue,
                          scrollRegionEnd: maxKeyValue,
                          handleStart: maxKeyValue - viewModel.keyValueAtTop,
                          handleEnd: maxKeyValue -
                              viewModel.keyValueAtTop +
                              constraints.maxHeight / viewModel.keyHeight,
                          onChange: (event) {
                            viewModel.keyValueAtTop =
                                maxKeyValue - event.handleStart;
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
  }
}

class _PianoRollCanvasCursor extends StatefulWidget {
  final Widget? child;

  const _PianoRollCanvasCursor({this.child});

  @override
  State<_PianoRollCanvasCursor> createState() => _PianoRollCanvasCursorState();
}

class _PianoRollCanvasCursorState extends State<_PianoRollCanvasCursor> {
  MouseCursor cursor = MouseCursor.defer;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PianoRollViewModel>(context);

    return MouseRegion(
      cursor: cursor,
      onHover: (e) {
        final pos = e.localPosition;

        final contentUnderCursor = viewModel.getContentUnderCursor(pos);
        final newCursor = contentUnderCursor.resizeHandle != null
            ? SystemMouseCursors.resizeLeftRight
            : contentUnderCursor.note != null
                ? SystemMouseCursors.move
                : MouseCursor.defer;

        final note = contentUnderCursor.note?.metadata.id;
        if (note != viewModel.hoveredNote) {
          viewModel.hoveredNote = note;
        }

        if (cursor == newCursor) return;

        setState(() {
          cursor = newCursor;
        });
      },
      onExit: (e) {
        viewModel.hoveredNote = null;
      },
      child: widget.child,
    );
  }
}
