/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/vertical_scale_control.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/panel.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_event_listener.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/editors/shared/tool_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;

import 'package:provider/provider.dart';

import '../shared/helpers/time_helpers.dart';
import '../shared/helpers/types.dart';
import '../shared/timeline/timeline_notification_handler.dart';
import 'helpers.dart';
import 'piano_roll_grid.dart';
import '../shared/timeline/timeline.dart';
import 'piano_control.dart';

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
  const PianoRoll({Key? key}) : super(key: key);

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
/// about updates to the [TimeRange] without re-rendering [Arranger].
///
/// We provide the [TimeRange] to the tree because some widgets, such as
/// [Timeline], are shared between editors, and they need to access the
/// [TimeRange] via a [Provider].
class PianoRollTimeViewProvider extends StatelessObserverWidget {
  final Widget? child;

  const PianoRollTimeViewProvider({Key? key, this.child}) : super(key: key);

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

    return SizedBox(
      height: 26,
      child: Row(
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
                            timeView: timeView,
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
              startIcon: Icons.kebab,
              onPress: () => menuController.open?.call(),
            ),
          ),
          const SizedBox(width: 4),
          const ToolSelector(selectedTool: EditorTool.pencil),
        ],
      ),
    );
  }
}

class _PianoRollContent extends StatefulWidget {
  const _PianoRollContent({
    Key? key,
  }) : super(key: key);

  @override
  State<_PianoRollContent> createState() => _PianoRollContentState();
}

class _PianoRollContentState extends State<_PianoRollContent>
    with TickerProviderStateMixin {
  double footerHeight = 61;
  double pianoControlWidth = 69;

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

  // Fields for key value at top animation

  late final AnimationController _keyValueAtTopAnimationController =
      AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
  );

  double _lastKeyValueAtTop = 0;

  late final Tween<double> _keyValueAtTopTween =
      Tween<double>(begin: _lastKeyValueAtTop, end: _lastKeyValueAtTop);

  late final Animation<double> _keyValueAtTopAnimation =
      _keyValueAtTopTween.animate(
    CurvedAnimation(
      parent: _keyValueAtTopAnimationController,
      curve: Curves.easeOutExpo,
    ),
  );

  mobx.ReactionDisposer? viewModelReactionDisposer;

  @override
  void dispose() {
    _timeViewAnimationController.dispose();
    _keyValueAtTopAnimationController.dispose();
    viewModelReactionDisposer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final viewModel = Provider.of<PianoRollViewModel>(context);

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

    // Updates the key value at top animation if the position has changed
    if (viewModel.keyValueAtTop != _lastKeyValueAtTop) {
      _keyValueAtTopTween.begin = _keyValueAtTopAnimation.value;
      _keyValueAtTopAnimationController.reset();
      _keyValueAtTopTween.end = viewModel.keyValueAtTop;
      _keyValueAtTopAnimationController.forward();
      _lastKeyValueAtTop = viewModel.keyValueAtTop;
    }

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
            SizedBox(width: pianoControlWidth),
            Container(color: Theme.panel.border, width: 1),
            Expanded(
              child: TimelineNotificationHandler(
                timelineKind: TimelineKind.pattern,
                patternID: pattern?.id,
                child: Timeline.pattern(
                  timeViewAnimationController: _timeViewAnimationController,
                  timeViewStartAnimation: _timeViewStartAnimation,
                  timeViewEndAnimation: _timeViewEndAnimation,
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
        animation: _keyValueAtTopAnimationController,
        builder: (context, child) {
          return PianoControl(
            keyValueAtTop: _keyValueAtTopAnimation.value,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              PianoRollGrid(
                timeViewAnimationController: _timeViewAnimationController,
                timeViewStartAnimation: _timeViewStartAnimation,
                timeViewEndAnimation: _timeViewEndAnimation,
                keyHeight: viewModel.keyHeight,
                keyValueAtTopAnimationController:
                    _keyValueAtTopAnimationController,
                keyValueAtTopAnimation: _keyValueAtTopAnimation,
              ),
              ClipRect(
                child: AnimatedBuilder(
                  animation: _keyValueAtTopAnimationController,
                  builder: (context, child) {
                    return AnimatedBuilder(
                      animation: _timeViewAnimationController,
                      builder: (context, child) {
                        return Observer(builder: (context) {
                          final notes = getPattern()
                                  ?.notes[project.activeGeneratorID]
                                  ?.toList() ??
                              [];

                          final noteWidgets = notes
                              .map(
                                (note) => LayoutId(
                                  id: note.id,
                                  child: NoteWidget(noteID: note.id),
                                ),
                              )
                              .toList();

                          return CustomMultiChildLayout(
                            delegate: NoteLayoutDelegate(
                              notes: notes,
                              keyHeight: viewModel.keyHeight,
                              keyValueAtTop: _keyValueAtTopAnimation.value,
                              timeViewStart: _timeViewStartAnimation.value,
                              timeViewEnd: _timeViewEndAnimation.value,
                            ),
                            children: noteWidgets,
                          );
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );

    return Panel(
      orientation: PanelOrientation.bottom,
      panelStartSize: 89,
      separatorSize: 6,
      panelContent: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.panel.border),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                SizedBox(width: pianoControlWidth + 1),
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
                      minHandleSize: project.song.ticksPerQuarter *
                          4, // TODO: time signature
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
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      child: Column(
                        children: [
                          timeline,
                          Container(color: Theme.panel.border, height: 1),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                pianoControl,
                                Container(color: Theme.panel.border, width: 1),
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
    );
  }
}

class NoteLayoutDelegate extends MultiChildLayoutDelegate {
  NoteLayoutDelegate({
    required this.notes,
    required this.keyHeight,
    required this.keyValueAtTop,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  final List<NoteModel> notes;
  final double timeViewStart;
  final double timeViewEnd;
  final double keyValueAtTop;
  final double keyHeight;

  @override
  void performLayout(Size size) {
    for (var note in notes) {
      final y = keyValueToPixels(
              keyValue: note.key.toDouble(),
              keyValueAtTop: keyValueAtTop,
              keyHeight: keyHeight) -
          keyHeight +
          // this is why I want Dart support for Prettier
          1;
      final height = keyHeight.toDouble() - 1;
      final startX = timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: note.offset.toDouble()) +
          1;
      final width = timeToPixels(
              timeViewStart: timeViewStart,
              timeViewEnd: timeViewEnd,
              viewPixelWidth: size.width,
              time: timeViewStart + note.length.toDouble()) -
          1;

      layoutChild(
        note.id,
        BoxConstraints(maxHeight: height, maxWidth: max(width, 0)),
      );
      positionChild(note.id, Offset(startX, y));
    }
  }

  @override
  bool shouldRelayout(covariant NoteLayoutDelegate oldDelegate) {
    if (oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.notes.length != notes.length ||
        oldDelegate.keyHeight != keyHeight ||
        oldDelegate.keyValueAtTop != keyValueAtTop) return true;
    for (var i = 0; i < notes.length; i++) {
      var oldNote = oldDelegate.notes[i];
      var newNote = notes[i];

      // No re-layout on velocity. I think this is okay?
      if (oldNote.key != newNote.key ||
          oldNote.length != newNote.length ||
          oldNote.offset != newNote.offset) {
        return true;
      }
    }
    return false;
  }
}

class NoteWidget extends StatefulWidget {
  const NoteWidget({Key? key, required this.noteID}) : super(key: key);

  final ID noteID;

  @override
  State<NoteWidget> createState() => _NoteWidgetState();
}

class _NoteWidgetState extends State<NoteWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // TODO: Send off notification on focus loss (?) or people will be very confused maybe
      onPointerDown: (e) {
        // NotePointerNotification(
        //   isRightClick: e.buttons == kSecondaryMouseButton,
        //   pressed: true,
        //   noteID: 1,
        // ).dispatch(context);
        // PianoRollNotification().dispatch(context);
      },
      // onPointerUp: (e) {
      //   NotePointerNotification(
      //     isRightClick: e.buttons == kSecondaryMouseButton,
      //     pressed: false,
      //     noteID: 1,
      //   ).dispatch(context);
      // },
      child: MouseRegion(
        onEnter: (e) {
          setState(() {
            isHovered = true;
          });
        },
        onExit: (e) {
          setState(() {
            isHovered = false;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(
                    1, 166, isHovered ? 0.4 : 0.46, isHovered ? 0.35 : 0.31)
                .toColor(),
            borderRadius: const BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
    );
  }
}
