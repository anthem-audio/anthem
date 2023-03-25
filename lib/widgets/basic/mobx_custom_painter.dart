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

/// A wrapper for [CustomPaint] that interfacees with [CustomPainterObserver].
class CustomPaintObserver extends StatefulWidget {
  final CustomPainterObserver Function()? painterBuilder;
  final CustomPainterObserver Function()? foregroundPainterBuilder;
  final Size size;
  final bool isComplex;
  final bool willChange;
  final Widget? child;

  const CustomPaintObserver({
    Key? key,
    this.painterBuilder,
    this.foregroundPainterBuilder,
    this.size = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    this.child,
  }) : super(key: key);

  @override
  State<CustomPaintObserver> createState() => _CustomPaintObserverState();
}

class _CustomPaintObserverState extends State<CustomPaintObserver> {
  _SharedState? painterSharedState;
  _SharedState? foregroundPainterSharedState;

  @override
  void initState() {
    super.initState();

    if (widget.painterBuilder != null) {
      painterSharedState = _SharedState(invalidatePainter);
    }

    if (widget.foregroundPainterBuilder != null) {
      foregroundPainterSharedState = _SharedState(invalidateForegroundPainter);
    }
  }

  @override
  void dispose() {
    painterSharedState?.cleanup?.call();
    foregroundPainterSharedState?.cleanup?.call();
    super.dispose();
  }

  void invalidatePainter() {
    setState(() {
      painterSharedState!.isDirty = true;
    });
  }

  void invalidateForegroundPainter() {
    setState(() {
      foregroundPainterSharedState!.isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    CustomPainterObserver? foregroundPainter;

    if (widget.foregroundPainterBuilder != null) {
      foregroundPainter = widget.foregroundPainterBuilder!.call();
      foregroundPainter._sharedState = foregroundPainterSharedState;
    }

    CustomPainterObserver? painter;

    if (widget.painterBuilder != null) {
      painter = widget.painterBuilder!.call();
      painter._sharedState = painterSharedState;
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
  _SharedState? _sharedState;

  void observablePaint(Canvas canvas, Size size);

  // Should not be overridden.
  @override
  void paint(Canvas canvas, Size size) {
    // Very awful. A ReactionImpl didn't work so here we are.
    _sharedState!.first = true;
    _sharedState!.cleanup = autorun((a) {
      if (!_sharedState!.first) {
        _sharedState!.invalidate();
        _sharedState!.cleanup!.call();
        return;
      }
      _sharedState!.first = false;
      observablePaint(canvas, size);
    });
    _sharedState!.isDirty = false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return _sharedState!.isDirty;
  }
}

class _SharedState {
  _SharedState(this.invalidate);

  Function invalidate;
  bool first = true;
  ReactionDisposer? cleanup;

  var isDirty = false;
}
