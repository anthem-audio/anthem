/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
// ignore: implementation_imports
import 'package:mobx/src/core.dart' show ReactionImpl;

/// A [CustomPainter] that repaints when observables accessed by
/// [observablePaint] change.
abstract class CustomPainterObserver extends CustomPainter {
  CustomPainterObserver({String? debugName})
    : _tracker = _MobxPaintTracker(name: debugName ?? 'CustomPainterObserver');

  final _MobxPaintTracker _tracker;

  void observablePaint(Canvas canvas, Size size);

  @override
  void addListener(VoidCallback listener) {
    _tracker.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _tracker.removeListener(listener);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _tracker.track(() {
      observablePaint(canvas, size);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _MobxPaintTracker extends ChangeNotifier {
  _MobxPaintTracker({required this.name});

  final String name;
  ReactionImpl? _reaction;
  int _listenerCount = 0;
  bool _isScheduled = false;

  void track(VoidCallback paint) {
    if (_listenerCount == 0) {
      paint();
      return;
    }

    (_reaction ??= ReactionImpl(
      mainContext,
      _invalidate,
      name: name,
      onError: _onError,
    )).track(paint);
  }

  @override
  void addListener(VoidCallback listener) {
    _listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_listenerCount > 0) {
      _listenerCount--;
    }

    super.removeListener(listener);

    if (_listenerCount == 0) {
      _reaction?.dispose();
      _reaction = null;
      _isScheduled = false;
    }
  }

  void _invalidate() {
    _notifyListenersImmediatelyOrDelayed();
  }

  void _notifyListenersImmediatelyOrDelayed() async {
    if (_isScheduled || _listenerCount == 0) {
      return;
    }

    _isScheduled = true;

    final scheduler = SchedulerBinding.instance;
    final shouldWait =
        scheduler.schedulerPhase != SchedulerPhase.idle &&
        scheduler.schedulerPhase != SchedulerPhase.postFrameCallbacks;

    if (shouldWait) {
      await scheduler.endOfFrame;
    }

    _isScheduled = false;

    if (_listenerCount == 0) {
      return;
    }

    notifyListeners();
  }

  void _onError(Object error, Reaction reaction) {
    FlutterError.reportError(
      FlutterErrorDetails(
        library: 'anthem',
        exception: error,
        stack: error is Error ? error.stackTrace : null,
        context: ErrorDescription('From reaction of $name.'),
      ),
    );
  }
}
