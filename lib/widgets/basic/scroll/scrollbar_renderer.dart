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

// Scroll forward/backward buttons
const double _mainAxisButtonSize = 17;

enum ScrollbarDirection { horizontal, vertical }

class ScrollbarRenderer extends StatefulWidget {
  final double minHandlePixelSize;

  // Size of the scroll region. The units don't matter, because the handle
  // position must be given in the same units.
  final double scrollRegionStart;
  final double scrollRegionEnd;

  // Size of the handle, relative to the scroll region.
  final double handleStart;
  final double handleEnd;

  const ScrollbarRenderer({
    Key? key,
    this.minHandlePixelSize = 20,
    required this.scrollRegionStart,
    required this.scrollRegionEnd,
    required this.handleStart,
    required this.handleEnd,
  }) : super(key: key);

  @override
  State<ScrollbarRenderer> createState() => _ScrollbarRendererState();
}

class _ScrollbarRendererState extends State<ScrollbarRenderer> {
  bool _isThumbPressed = false;
  double _localStartPos = -1;
  double _scrollAreaStartPos = -1;

  // void _handleDown(double pos, double containerMainAxisLength) {
  //   _localStartPos = pos;
  //   _scrollAreaStartPos = widget.controller.position.pixels;
  // }

  // void _handleMove(double pos, double containerMainAxisLength) {
  //   final delta = pos - _localStartPos;
  //   final normalizedThumbSize = inside / (before + inside + after);
  //   final normalizedDelta = delta / containerMainAxisLength;
  //   final scrollAreaStart = widget.controller.position.minScrollExtent;
  //   final scrollAreaEnd = widget.controller.position.maxScrollExtent;
  //   final scrollAreaSize = scrollAreaEnd - scrollAreaStart;
  //   final targetPos =
  //       normalizedDelta * (scrollAreaSize * (1 / (1 - normalizedThumbSize))) +
  //           _scrollAreaStartPos +
  //           scrollAreaStart;
  //   widget.controller.jumpTo(targetPos.clamp(scrollAreaStart, scrollAreaEnd));
  // }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxHeight > constraints.maxWidth;
        final isHorizontal = constraints.maxWidth > constraints.maxHeight;

        // Calculate handle start & end position
        final mainAxisSize =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final trackSize = mainAxisSize - 2 * _mainAxisButtonSize;

        final scrollRegionSize =
            widget.scrollRegionEnd - widget.scrollRegionStart;
        final normalizedHandleStart =
            (widget.handleStart - widget.scrollRegionStart) / scrollRegionSize;
        final normalizedHandleEnd =
            (widget.handleEnd - widget.scrollRegionStart) / scrollRegionSize;

        var handleStart =
            mainAxisSize * normalizedHandleStart + _mainAxisButtonSize;
        var handleEnd =
            mainAxisSize * normalizedHandleEnd + _mainAxisButtonSize;

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

        final isDisabled = widget.handleStart <= widget.scrollRegionStart &&
            widget.handleEnd >= widget.scrollRegionEnd;

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
                    startIcon: isHorizontal
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
                    startIcon: isHorizontal
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

              // Scrollbar track with handle
              Positioned(
                left: isVertical ? 1 : handleStart,
                right: isVertical ? 1 : mainAxisSize - handleEnd,
                top: isHorizontal ? 1 : handleStart,
                bottom: isHorizontal ? 1 : mainAxisSize - handleEnd,
                child: GestureDetector(
                  onVerticalDragDown: (details) {
                    // if (!isVertical) return;
                    // _handleDown(
                    //     details.localPosition.dy, context.size?.height ?? 1);
                  },
                  onVerticalDragUpdate: (details) {
                    // if (!isVertical) return;
                    // _handleMove(
                    //     details.localPosition.dy, context.size?.height ?? 1);
                  },
                  onHorizontalDragDown: (details) {
                    // if (!isHorizontal) return;
                    // _handleDown(details.localPosition.dx, context.size?.width ?? 1);
                  },
                  onHorizontalDragUpdate: (details) {
                    // if (!isHorizontal) return;
                    // _handleMove(details.localPosition.dx, context.size?.width ?? 1);
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
