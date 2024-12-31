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
import '../button.dart';
import '../icon.dart';

// Scroll forward/backward buttons (doesn't include divider)
const double _mainAxisButtonSize = 16;

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

  void _handleDown(double pos) {
    startHandleStart = widget.handleStart;
    startHandleEnd = widget.handleEnd;
    startPos = pos;
  }

  void _handleMove(double pos, double trackSize) {
    final scrollRegionSize = widget.scrollRegionEnd - widget.scrollRegionStart;

    // Delta since mouse down
    final pixelDelta = pos - startPos;

    final handleDelta = (pixelDelta / trackSize) * scrollRegionSize;

    var handleStart = startHandleStart + handleDelta;
    var handleEnd = startHandleEnd + handleDelta;

    if (!widget.canScrollPastStart) {
      final startOvershoot =
          (widget.scrollRegionStart - handleStart).clamp(0, double.infinity);
      handleStart += startOvershoot;
      handleEnd += startOvershoot;
    }

    if (!widget.canScrollPastEnd) {
      final endOvershoot =
          (handleEnd - widget.scrollRegionEnd).clamp(0, double.infinity);
      handleStart -= endOvershoot;
      handleEnd -= endOvershoot;
    }

    if (handleStart == widget.handleStart && handleEnd == widget.handleEnd) {
      return;
    }

    widget.onChange?.call(ScrollbarChangeEvent(
      handleStart: handleStart,
      handleEnd: handleEnd,
    ));
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

        final mainAxisSize =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final trackSize = mainAxisSize - 2 * _mainAxisButtonSize;

        // Calculate handle start & end position

        final scrollRegionSize =
            widget.scrollRegionEnd - widget.scrollRegionStart;
        final normalizedHandleStart =
            (widget.handleStart - widget.scrollRegionStart) / scrollRegionSize;
        final normalizedHandleEnd =
            (widget.handleEnd - widget.scrollRegionStart) / scrollRegionSize;

        var handleStart =
            trackSize * normalizedHandleStart + _mainAxisButtonSize;
        var handleEnd = trackSize * normalizedHandleEnd + _mainAxisButtonSize;

        // Ensure handle size is at least the supplied minimum
        if (handleEnd - handleStart < widget.minHandlePixelSize) {
          final extraSizeNeeded =
              widget.minHandlePixelSize - (handleEnd - handleStart);

          handleEnd += extraSizeNeeded / 2;
          handleStart -= extraSizeNeeded / 2;
        }

        // Correct for out of bounds
        if (handleStart < _mainAxisButtonSize) {
          handleStart = _mainAxisButtonSize;
        }
        if (handleEnd > _mainAxisButtonSize + trackSize) {
          handleEnd = _mainAxisButtonSize + trackSize;
        }
        if (handleStart >
            _mainAxisButtonSize + trackSize - widget.minHandlePixelSize) {
          handleStart =
              _mainAxisButtonSize + trackSize - widget.minHandlePixelSize;
        }
        if (handleEnd < _mainAxisButtonSize + widget.minHandlePixelSize) {
          handleEnd = _mainAxisButtonSize + widget.minHandlePixelSize;
        }

        // Create flex children for handle
        final flexChildren = <Widget>[];

        final border = Container(
          width: isHorizontal ? 1 : null,
          height: isVertical ? 1 : null,
          color: Theme.panel.border,
        );

        final isDisabled = widget.disableAtFullSize &&
            (widget.handleStart <= widget.scrollRegionStart &&
                widget.handleEnd >= widget.scrollRegionEnd);

        flexChildren.addAll([
          border,
          Flexible(
            flex: 1,
            child: Button(
              hideBorder: true,
              expand: true,
              borderRadius: BorderRadius.circular(1),
              variant: isDisabled ? ButtonVariant.label : ButtonVariant.dark,
            ),
          ),
          border,
        ]);

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // Border
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.panel.border,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Start button
              Positioned(
                left: 1,
                top: 1,
                right: isVertical ? 1 : null,
                bottom: isHorizontal ? 1 : null,
                child: Container(
                  width: isHorizontal ? _mainAxisButtonSize : null,
                  height: isVertical ? _mainAxisButtonSize : null,
                  decoration: BoxDecoration(
                    border: isHorizontal
                        ? Border(
                            right: BorderSide(color: Theme.panel.border),
                          )
                        : Border(
                            bottom: BorderSide(color: Theme.panel.border),
                          ),
                  ),
                  child: Button(
                    hideBorder: true,
                    variant: ButtonVariant.ghost,
                    icon: isHorizontal
                        ? Icons.scrollbar.arrowLeft
                        : Icons.scrollbar.arrowUp,
                    contentPadding: EdgeInsets.zero,
                    borderRadius: isHorizontal
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(4),
                            right: Radius.circular(1),
                          )
                        : const BorderRadius.vertical(
                            top: Radius.circular(4),
                            bottom: Radius.circular(1),
                          ),
                  ),
                ),
              ),

              // End button
              Positioned(
                left: isVertical ? 1 : null,
                top: isHorizontal ? 1 : null,
                right: 1,
                bottom: 1,
                child: Container(
                  width: isHorizontal ? _mainAxisButtonSize : null,
                  height: isVertical ? _mainAxisButtonSize : null,
                  decoration: BoxDecoration(
                    border: isHorizontal
                        ? Border(
                            left: BorderSide(color: Theme.panel.border),
                          )
                        : Border(
                            top: BorderSide(color: Theme.panel.border),
                          ),
                  ),
                  child: Button(
                    hideBorder: true,
                    variant: ButtonVariant.ghost,
                    icon: isHorizontal
                        ? Icons.scrollbar.arrowRight
                        : Icons.scrollbar.arrowDown,
                    contentPadding: EdgeInsets.zero,
                    borderRadius: isHorizontal
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(1),
                            right: Radius.circular(4),
                          )
                        : const BorderRadius.vertical(
                            top: Radius.circular(1),
                            bottom: Radius.circular(4),
                          ),
                  ),
                ),
              ),

              // Scrollbar handle
              Positioned(
                left: isVertical ? 1 : handleStart,
                right: isVertical ? 1 : mainAxisSize - handleEnd,
                top: isHorizontal ? 1 : handleStart,
                bottom: isHorizontal ? 1 : mainAxisSize - handleEnd,
                child: Listener(
                  onPointerDown: (event) {
                    _handleDown(isHorizontal
                        ? event.localPosition.dx
                        : event.localPosition.dy);
                  },
                  onPointerMove: (event) {
                    _handleMove(
                        isHorizontal
                            ? event.localPosition.dx
                            : event.localPosition.dy,
                        trackSize);
                  },
                  child: isHorizontal
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: flexChildren,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: flexChildren,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
