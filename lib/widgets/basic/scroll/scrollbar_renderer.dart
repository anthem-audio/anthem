/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../theme.dart';

enum ScrollbarDirection { horizontal, vertical }

class ScrollbarChangeEvent {
  final double handleStart;
  final double handleEnd;

  const ScrollbarChangeEvent({
    required this.handleStart,
    required this.handleEnd,
  });
}

class _ScrollbarGeometry {
  final double handleStart;
  final double handleEnd;
  final double logicalTravel;
  final double pixelTravel;

  const _ScrollbarGeometry({
    required this.handleStart,
    required this.handleEnd,
    required this.logicalTravel,
    required this.pixelTravel,
  });
}

_ScrollbarGeometry _calculateScrollbarGeometry({
  required double trackSize,
  required double scrollRegionStart,
  required double scrollRegionEnd,
  required double handleStart,
  required double handleEnd,
  required double minHandlePixelSize,
  required double minHandleSize,
}) {
  final scrollRegionSize = scrollRegionEnd - scrollRegionStart;
  final handleSize = math.max(0.0, handleEnd - handleStart);

  if (trackSize <= 0 || scrollRegionSize <= 0) {
    return const _ScrollbarGeometry(
      handleStart: 0,
      handleEnd: 0,
      logicalTravel: 0,
      pixelTravel: 0,
    );
  }

  final effectiveMinHandleSize = math.min(
    scrollRegionSize,
    math.max(0.0, minHandleSize),
  );
  final visualHandleRegionSize = math.min(
    scrollRegionSize,
    math.max(handleSize, effectiveMinHandleSize),
  );
  final effectiveMinHandlePixelSize = math.min(
    trackSize,
    math.max(0.0, minHandlePixelSize),
  );
  final visualHandleSize = math.min(
    trackSize,
    math.max(
      effectiveMinHandlePixelSize,
      trackSize * visualHandleRegionSize / scrollRegionSize,
    ),
  );

  final logicalTravel = math.max(0.0, scrollRegionSize - handleSize);
  final pixelTravel = math.max(0.0, trackSize - visualHandleSize);
  final progress = logicalTravel == 0
      ? 0.0
      : ((handleStart - scrollRegionStart) / logicalTravel)
            .clamp(0.0, 1.0)
            .toDouble();
  final visualHandleStart = progress * pixelTravel;

  return _ScrollbarGeometry(
    handleStart: visualHandleStart,
    handleEnd: visualHandleStart + visualHandleSize,
    logicalTravel: logicalTravel,
    pixelTravel: pixelTravel,
  );
}

class ScrollbarRenderer extends StatefulWidget {
  // When rendering, the handle will never be smaller than this
  final double minHandlePixelSize;

  final double minHandleSize;

  // Size of the scroll region. The units don't matter, because the handle
  // position must be given in the same units.
  final double scrollRegionStart;
  final double scrollRegionEnd;

  // Size of the handle, relative to the scroll region.
  final double handleStart;
  final double handleEnd;

  final bool canScrollPastStart;
  final bool canScrollPastEnd;

  final void Function(ScrollbarChangeEvent event)? onChange;

  /// If true, the scrollbar will show as disabled when the start is 0 and the
  /// end is 1.
  final bool disableAtFullSize;

  const ScrollbarRenderer({
    super.key,
    this.minHandlePixelSize = 24,
    this.minHandleSize = 0,
    required this.scrollRegionStart,
    required this.scrollRegionEnd,
    required this.handleStart,
    required this.handleEnd,
    this.onChange,
    this.canScrollPastStart = false,
    this.canScrollPastEnd = false,
    this.disableAtFullSize = true,
  });

  @override
  State<ScrollbarRenderer> createState() => _ScrollbarRendererState();
}

class _ScrollbarRendererState extends State<ScrollbarRenderer> {
  double startHandleStart = -1;
  double startHandleEnd = -1;
  double startPos = -1;

  bool hovered = false;
  bool pressed = false;

  void _handleDown(double pos) {
    startHandleStart = widget.handleStart;
    startHandleEnd = widget.handleEnd;
    startPos = pos;
    setState(() {
      pressed = true;
    });
  }

  void _handleMove(double pos, double trackSize) {
    if (trackSize <= 0) {
      return;
    }

    final scrollRegionSize = widget.scrollRegionEnd - widget.scrollRegionStart;

    // Delta since mouse down
    final pixelDelta = pos - startPos;

    final geometry = _calculateScrollbarGeometry(
      trackSize: trackSize,
      scrollRegionStart: widget.scrollRegionStart,
      scrollRegionEnd: widget.scrollRegionEnd,
      handleStart: startHandleStart,
      handleEnd: startHandleEnd,
      minHandlePixelSize: widget.minHandlePixelSize,
      minHandleSize: widget.minHandleSize,
    );
    final handleDelta = geometry.pixelTravel == 0
        ? (pixelDelta / trackSize) * scrollRegionSize
        : (pixelDelta / geometry.pixelTravel) * geometry.logicalTravel;

    var handleStart = startHandleStart + handleDelta;
    var handleEnd = startHandleEnd + handleDelta;

    if (!widget.canScrollPastStart) {
      final startOvershoot = (widget.scrollRegionStart - handleStart).clamp(
        0,
        double.infinity,
      );
      handleStart += startOvershoot;
      handleEnd += startOvershoot;
    }

    if (!widget.canScrollPastEnd) {
      final endOvershoot = (handleEnd - widget.scrollRegionEnd).clamp(
        0,
        double.infinity,
      );
      handleStart -= endOvershoot;
      handleEnd -= endOvershoot;
    }

    bool epsilonEquals(double a, double b) =>
        (a - b) < 1e-12 && (a - b) > -1e-12;

    if (epsilonEquals(handleStart, widget.handleStart) &&
        epsilonEquals(handleEnd, widget.handleEnd)) {
      return;
    }

    widget.onChange?.call(
      ScrollbarChangeEvent(handleStart: handleStart, handleEnd: handleEnd),
    );
  }

  void _handleUp() {
    setState(() {
      pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollRegionEnd - widget.scrollRegionStart == 0) {
      return SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxHeight > constraints.maxWidth;
        final isHorizontal = constraints.maxWidth > constraints.maxHeight;

        final mainAxisSize = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final trackSize = mainAxisSize;

        final geometry = _calculateScrollbarGeometry(
          trackSize: trackSize,
          scrollRegionStart: widget.scrollRegionStart,
          scrollRegionEnd: widget.scrollRegionEnd,
          handleStart: widget.handleStart,
          handleEnd: widget.handleEnd,
          minHandlePixelSize: widget.minHandlePixelSize,
          minHandleSize: widget.minHandleSize,
        );
        final handleStart = geometry.handleStart;
        final handleEnd = geometry.handleEnd;

        final isDisabled =
            widget.disableAtFullSize &&
            (widget.handleStart <= widget.scrollRegionStart &&
                widget.handleEnd >= widget.scrollRegionEnd);

        var handleColor = AnthemTheme.panel.scrollbar;
        if (isDisabled) {
          handleColor = handleColor.withValues(alpha: 0.5);
        } else if (hovered && !pressed) {
          handleColor = AnthemTheme.panel.scrollbarHover;
        } else if (pressed) {
          handleColor = AnthemTheme.panel.scrollbarPress;
        }

        return Stack(
          children: [
            // Scrollbar handle
            Positioned(
              left: isVertical ? 1 : handleStart,
              right: isVertical ? 1 : mainAxisSize - handleEnd,
              top: isHorizontal ? 1 : handleStart,
              bottom: isHorizontal ? 1 : mainAxisSize - handleEnd,
              child: MouseRegion(
                onEnter: (e) {
                  setState(() {
                    hovered = true;
                  });
                },
                onExit: (e) {
                  setState(() {
                    hovered = false;
                  });
                },
                child: Listener(
                  onPointerDown: (event) {
                    _handleDown(
                      isHorizontal
                          ? event.localPosition.dx
                          : event.localPosition.dy,
                    );
                  },
                  onPointerMove: (event) {
                    _handleMove(
                      isHorizontal
                          ? event.localPosition.dx
                          : event.localPosition.dy,
                      trackSize,
                    );
                  },
                  onPointerUp: (event) {
                    _handleUp();
                  },
                  onPointerCancel: (event) {
                    _handleUp();
                  },
                  child: Container(
                    // The mouse handlers won't recognize the padding area as
                    // part of the handle without this
                    color: Color(0x00000000),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
