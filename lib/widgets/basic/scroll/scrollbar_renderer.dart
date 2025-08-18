/*
  Copyright (C) 2021 - 2022 Joshua Wade

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
    final scrollRegionSize = widget.scrollRegionEnd - widget.scrollRegionStart;

    // Delta since mouse down
    final pixelDelta = pos - startPos;

    final handleDelta = (pixelDelta / trackSize) * scrollRegionSize;

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

    if (handleStart == widget.handleStart && handleEnd == widget.handleEnd) {
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
      throw ArgumentError('Scroll region must have a nonzero size.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxHeight > constraints.maxWidth;
        final isHorizontal = constraints.maxWidth > constraints.maxHeight;

        final mainAxisSize = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final trackSize = mainAxisSize;

        // Calculate handle start & end position

        final scrollRegionSize =
            widget.scrollRegionEnd - widget.scrollRegionStart;
        final normalizedHandleStart =
            (widget.handleStart - widget.scrollRegionStart) / scrollRegionSize;
        final normalizedHandleEnd =
            (widget.handleEnd - widget.scrollRegionStart) / scrollRegionSize;

        var handleStart = trackSize * normalizedHandleStart;
        var handleEnd = trackSize * normalizedHandleEnd;

        // Ensure handle size is at least the supplied minimum
        if (handleEnd - handleStart < widget.minHandlePixelSize) {
          final extraSizeNeeded =
              widget.minHandlePixelSize - (handleEnd - handleStart);

          handleEnd += extraSizeNeeded / 2;
          handleStart -= extraSizeNeeded / 2;
        }

        // Correct for out of bounds
        if (handleStart < 0) {
          handleStart = 0;
        }
        if (handleEnd > trackSize) {
          handleEnd = trackSize;
        }
        if (handleStart > trackSize - widget.minHandlePixelSize) {
          handleStart = trackSize - widget.minHandlePixelSize;
        }
        if (handleEnd < 0 + widget.minHandlePixelSize) {
          handleEnd = 0 + widget.minHandlePixelSize;
        }

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
                cursor: SystemMouseCursors.click,
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
