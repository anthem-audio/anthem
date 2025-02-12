/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/background.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/widgets/editors/automation_editor/controller/automation_editor_controller.dart';
import 'package:anthem/widgets/editors/automation_editor/content_renderer.dart';
import 'package:anthem/widgets/editors/automation_editor/event_listener.dart';
import 'package:anthem/widgets/editors/automation_editor/point_context_menu.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/util/lazy_follower.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../shared/timeline/timeline.dart';

const noContentBars = 16;

class AutomationEditor extends StatefulWidget {
  const AutomationEditor({super.key});

  @override
  State<AutomationEditor> createState() => AutomationEditorState();
}

class AutomationEditorState extends State<AutomationEditor> {
  AutomationEditorViewModel? viewModel;
  AutomationEditorController? controller;

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    viewModel ??= AutomationEditorViewModel(timeView: TimeRange(0, 3072));
    controller ??=
        AutomationEditorController(viewModel: viewModel!, project: project);

    return Provider.value(
      value: viewModel!,
      child: Provider.value(
        value: controller!,
        child: const Background(
          type: BackgroundType.dark,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AutomationEditorHeader(),
                SizedBox(height: 4),
                Flexible(child: _AutomationEditorContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomationEditorHeader extends StatelessWidget {
  const _AutomationEditorHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Button(
            icon: Icons.kebab,
            width: 26,
          ),
        ],
      ),
    );
  }
}

class _AutomationEditorContent extends StatefulObserverWidget {
  const _AutomationEditorContent();

  @override
  State<_AutomationEditorContent> createState() =>
      _AutomationEditorContentState();
}

class _AutomationEditorContentState extends State<_AutomationEditorContent>
    with TickerProviderStateMixin {
  LazyFollowAnimationHelper? timeViewAnimationHelper;

  mobx.ReactionDisposer? animationTweenUpdaterDisposer;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AutomationEditorViewModel>(context);
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

    // Updates the animations whenever the vertical scroll position changes.
    animationTweenUpdaterDisposer ??= mobx.autorun((p0) {
      viewModel.timeView.start;
      viewModel.timeView.end;

      setState(() {});
    });

    final activePatternID = project.sequence.activePatternID;
    final pattern = project.sequence.patterns[activePatternID];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: ScrollbarRenderer(
            handleStart: viewModel.timeView.start,
            handleEnd: viewModel.timeView.end,
            scrollRegionStart: 0,
            scrollRegionEnd: pattern?.lastContent.toDouble() ??
                (project.sequence.ticksPerQuarter * 4 * noContentBars)
                    .toDouble(),
            canScrollPastEnd: true,
            disableAtFullSize: false,
            minHandleSize: project.sequence.ticksPerQuarter * 4,
            onChange: (event) {
              viewModel.timeView.start = event.handleStart;
              viewModel.timeView.end = event.handleEnd;
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.panel.border,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Provider.value(
                    value: viewModel.timeView,
                    child: SizedBox(
                      height: 21,
                      child: Timeline.pattern(
                        patternID: activePatternID,
                        timeViewStartAnimation: timeViewStartAnimItem.animation,
                        timeViewEndAnimation: timeViewEndAnimItem.animation,
                        timeViewAnimationController:
                            timeViewAnimationHelper!.animationController,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AutomationPointContextMenu(
                      child: AutomationEditorEventListener(
                        child: AnimatedBuilder(
                          animation:
                              timeViewAnimationHelper!.animationController,
                          builder: (context, child) {
                            return AutomationEditorContentRenderer(
                              timeViewStart:
                                  timeViewStartAnimItem.animation.value,
                              timeViewEnd: timeViewEndAnimItem.animation.value,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    timeViewAnimationHelper?.dispose();
    animationTweenUpdaterDisposer?.call();
    super.dispose();
  }
}
