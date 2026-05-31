/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/widgets/basic/lazy_follower.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'time_range_viewport.dart';

class TimeRangeAnimation {
  final TimeRangeViewport viewport;

  late final LazyFollowAnimationHelper _helper;
  int _lastAppliedMutationRevision = 0;

  TimeRangeAnimation({required this.viewport, required TickerProvider vsync}) {
    _helper = LazyFollowAnimationHelper(
      duration: 250,
      vsync: vsync,
      animateOnFirstUpdate: false,
      items: [
        LazyFollowItem(
          initialValue: viewport.target.start,
          getTarget: () => viewport.target.start,
          getShouldSnap: _shouldSnapToTarget,
        ),
        LazyFollowItem(
          initialValue: viewport.target.end,
          getTarget: () => viewport.target.end,
          getShouldSnap: _shouldSnapToTarget,
        ),
      ],
    );
  }

  AnimationController get controller => _helper.animationController;
  Animation<double> get start => _helper.items[0].animation;
  Animation<double> get end => _helper.items[1].animation;
  double get renderedStart => start.value;
  double get renderedEnd => end.value;

  bool _shouldSnapToTarget() {
    final lastMutation = viewport.lastMutation;
    return lastMutation.revision != _lastAppliedMutationRevision &&
        lastMutation.transition == TimeRangeTransition.immediate;
  }

  void update() {
    final latestMutationRevision = viewport.lastMutation.revision;
    _helper.update();
    _lastAppliedMutationRevision = latestMutationRevision;
  }

  void dispose() {
    _helper.dispose();
  }
}

typedef TimeRangeAnimationWidgetBuilder =
    Widget Function(
      BuildContext context,
      TimeRangeAnimation timeRangeAnimation,
    );

class TimeRangeAnimationBuilder extends StatefulObserverWidget {
  final TimeRangeViewport viewport;
  final TimeRangeAnimationWidgetBuilder builder;
  final void Function({
    required double timeRangeStart,
    required double timeRangeEnd,
  })?
  onRenderedTimeRangeChanged;

  const TimeRangeAnimationBuilder({
    super.key,
    required this.viewport,
    required this.builder,
    this.onRenderedTimeRangeChanged,
  });

  @override
  State<TimeRangeAnimationBuilder> createState() =>
      _TimeRangeAnimationBuilderState();
}

class _TimeRangeAnimationBuilderState extends State<TimeRangeAnimationBuilder>
    with SingleTickerProviderStateMixin {
  late TimeRangeAnimation _timeRangeAnimation;
  double? _lastNotifiedTimeRangeStart;
  double? _lastNotifiedTimeRangeEnd;

  @override
  void initState() {
    super.initState();
    _timeRangeAnimation = _createAnimation();
    _timeRangeAnimation.controller.addListener(_notifyRenderedTimeRangeChanged);
  }

  TimeRangeAnimation _createAnimation() {
    return TimeRangeAnimation(viewport: widget.viewport, vsync: this);
  }

  void _notifyRenderedTimeRangeChanged() {
    final onRenderedTimeRangeChanged = widget.onRenderedTimeRangeChanged;
    if (onRenderedTimeRangeChanged == null) {
      return;
    }

    final timeRangeStart = _timeRangeAnimation.renderedStart;
    final timeRangeEnd = _timeRangeAnimation.renderedEnd;
    if (_lastNotifiedTimeRangeStart == timeRangeStart &&
        _lastNotifiedTimeRangeEnd == timeRangeEnd) {
      return;
    }

    _lastNotifiedTimeRangeStart = timeRangeStart;
    _lastNotifiedTimeRangeEnd = timeRangeEnd;
    onRenderedTimeRangeChanged(
      timeRangeStart: timeRangeStart,
      timeRangeEnd: timeRangeEnd,
    );
  }

  @override
  void didUpdateWidget(covariant TimeRangeAnimationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(
      oldWidget.onRenderedTimeRangeChanged,
      widget.onRenderedTimeRangeChanged,
    )) {
      _lastNotifiedTimeRangeStart = null;
      _lastNotifiedTimeRangeEnd = null;
    }

    if (!identical(oldWidget.viewport, widget.viewport)) {
      _timeRangeAnimation.controller.removeListener(
        _notifyRenderedTimeRangeChanged,
      );
      _timeRangeAnimation.dispose();
      _lastNotifiedTimeRangeStart = null;
      _lastNotifiedTimeRangeEnd = null;
      _timeRangeAnimation = _createAnimation();
      _timeRangeAnimation.controller.addListener(
        _notifyRenderedTimeRangeChanged,
      );
    }
  }

  @override
  void dispose() {
    _timeRangeAnimation.controller.removeListener(
      _notifyRenderedTimeRangeChanged,
    );
    _timeRangeAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _timeRangeAnimation.update();
    _notifyRenderedTimeRangeChanged();

    return widget.builder(context, _timeRangeAnimation);
  }
}
