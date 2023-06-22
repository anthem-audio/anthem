/*
  Copyright (C) 2023 Joshua Wade

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
import 'package:anthem/widgets/editors/automation_editor/content_renderer.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../shared/timeline/timeline.dart';

class AutomationEditor extends StatefulWidget {
  const AutomationEditor({super.key});

  @override
  State<AutomationEditor> createState() => AutomationEditorState();
}

class AutomationEditorState extends State<AutomationEditor> {
  AutomationEditorViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    viewModel ??= AutomationEditorViewModel(timeView: TimeRange(0, 3072));

    return Provider.value(
      value: viewModel!,
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

  mobx.ReactionDisposer? animationTweenUpdaterDisposer;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AutomationEditorViewModel>(context);
    final project = Provider.of<ProjectModel>(context);

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

    // Updates the animations whenever the vertical scroll position changes.
    animationTweenUpdaterDisposer ??= mobx.autorun((p0) {
      viewModel.timeView.start;
      viewModel.timeView.end;

      setState(() {});
    });

    final activePatternID = project.song.activePatternID;
    final pattern = project.song.patterns[activePatternID];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: ScrollbarRenderer(
            handleStart: viewModel.timeView.start,
            handleEnd: viewModel.timeView.end,
            scrollRegionStart: 0,
            scrollRegionEnd: pattern?.getWidth().toDouble() ?? 3072 * 2,
            canScrollPastEnd: true,
            disableAtFullSize: pattern != null,
            minHandleSize: project.song.ticksPerQuarter * 4,
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
                        timeViewStartAnimation: _timeViewStartAnimation,
                        timeViewEndAnimation: _timeViewEndAnimation,
                        timeViewAnimationController:
                            _timeViewAnimationController,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _timeViewAnimationController,
                      builder: (context, child) {
                        return AutomationEditorContentRenderer(
                          timeViewStart: _timeViewStartAnimation.value,
                          timeViewEnd: _timeViewEndAnimation.value,
                        );
                      },
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
}
