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

import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
// ignore: implementation_imports
import 'package:mobx/src/core.dart' show ReactionImpl;

/// A wrapper for [CustomPaint] that interfaces with [CustomPainterObserver].
class CustomPaintObserver extends StatefulWidget {
  final CustomPainterObserver? painter;
  final CustomPainterObserver? foregroundPainter;
  final Size size;
  final bool isComplex;
  final bool willChange;
  final Widget? child;

  const CustomPaintObserver({
    Key? key,
    this.painter,
    this.foregroundPainter,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    this.child,
  }) : super(key: key);

  @override
  State<CustomPaintObserver> createState() => _CustomPaintObserverState();
}

class _CustomPaintObserverState extends State<CustomPaintObserver> {
  ReactionImpl? painterReaction;
  ReactionImpl? foregroundPainterReaction;

  _DirtyTracker? painterDirtyTracker;
  _DirtyTracker? foregroundPainterDirtyTracker;

  @override
  void initState() {
    super.initState();

    if (widget.painter != null) {
      painterReaction = ReactionImpl(
        mainContext,
        invalidatePainter,
        name: 'CustomPainterReaction',
      );
      painterDirtyTracker = _DirtyTracker();
    }

    if (widget.foregroundPainter != null) {
      foregroundPainterReaction = ReactionImpl(
        mainContext,
        invalidateForegroundPainter,
        name: 'CustomPainterForegroundReaction',
      );
      foregroundPainterDirtyTracker = _DirtyTracker();
    }
  }

  @override
  void dispose() {
    painterReaction?.dispose();
    foregroundPainterReaction?.dispose();
    super.dispose();
  }

  void invalidatePainter() {
    setState(() {
      painterDirtyTracker!.isDirty = true;
    });
  }

  void invalidateForegroundPainter() {
    setState(() {
      foregroundPainterDirtyTracker!.isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    CustomPainterObserver? foregroundPainter;

    if (widget.foregroundPainter != null) {
      foregroundPainter = widget.foregroundPainter!;
      foregroundPainter.reaction = foregroundPainterReaction!;
      foregroundPainter._dirtyTracker = foregroundPainterDirtyTracker!;
    }

    CustomPainterObserver? painter;

    if (widget.painter != null) {
      painter = widget.painter!;
      painter.reaction = painterReaction!;
      painter._dirtyTracker = painterDirtyTracker!;
    }

    return CustomPaint(
      foregroundPainter: foregroundPainter,
      painter: painter,
      size: widget.size,
      isComplex: widget.isComplex,
      willChange: widget.willChange,
      child: widget.child,
    );
  }
}

/// A [CustomPainter] that will re-render when any observables accessed by
/// [observablePaint] are changed. Must be used with [CustomPaintObserver].
abstract class CustomPainterObserver extends CustomPainter {
  ReactionImpl? reaction;
  _DirtyTracker? _dirtyTracker;

  void observablePaint(Canvas canvas, Size size);

  // Should not be overridden.
  @override
  void paint(Canvas canvas, Size size) {
    // TODO: This seems to only get dependencies once. I'm still not sure why.
    // Maybe I need a new reaction for each render??
    reaction!.track(() {
      observablePaint(canvas, size);
    });
    _dirtyTracker!.isDirty = false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return _dirtyTracker!.isDirty;
  }
}

class _DirtyTracker {
  var isDirty = false;
}
