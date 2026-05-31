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
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class TimeRangeAnimation {
  final LazyFollowAnimationHelper _helper;

  TimeRangeAnimation({
    required TimeRange timeRange,
    required TickerProvider vsync,
  }) : _helper = LazyFollowAnimationHelper(
         duration: 250,
         vsync: vsync,
         animateOnFirstUpdate: false,
         items: [
           LazyFollowItem(
             initialValue: timeRange.start,
             getTarget: () => timeRange.start,
           ),
           LazyFollowItem(
             initialValue: timeRange.end,
             getTarget: () => timeRange.end,
           ),
         ],
       );

  AnimationController get controller => _helper.animationController;
  Animation<double> get start => _helper.items[0].animation;
  Animation<double> get end => _helper.items[1].animation;
  double get renderedStart => start.value;
  double get renderedEnd => end.value;

  void update() {
    _helper.update();
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
  final TimeRange timeRange;
  final TimeRangeAnimationWidgetBuilder builder;
  final void Function({
    required double timeRangeStart,
    required double timeRangeEnd,
  })?
  onRenderedTimeRangeChanged;

  const TimeRangeAnimationBuilder({
    super.key,
    required this.timeRange,
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
    return TimeRangeAnimation(timeRange: widget.timeRange, vsync: this);
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

    if (!identical(oldWidget.timeRange, widget.timeRange)) {
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
