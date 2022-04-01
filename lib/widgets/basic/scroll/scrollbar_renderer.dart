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

const double _mainAxisButtonSize = 17;

enum ScrollbarDirection { horizontal, vertical }

class ScrollbarRenderer extends StatefulWidget {
  final double? width;
  final double? height;

  const ScrollbarRenderer({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<ScrollbarRenderer> createState() => _ScrollbarRendererState();
}

class _ScrollbarRendererState extends State<ScrollbarRenderer> {
  bool _isThumbPressed = false;
  double _localStartPos = -1;
  double _scrollAreaStartPos = -1;

  int before = 0;
  int inside = 5;
  int after = 2;

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

        final flexChildren = <Widget>[];
        if (before > 0) {
          flexChildren.add(Spacer(
            flex: before,
          ));
        }

        final border = Container(
          width: isHorizontal ? 1 : null,
          height: isVertical ? 1 : null,
          color: Theme.panel.border,
        );

        flexChildren.addAll([
          border,
          Flexible(
            flex: inside,
            child: Button(
              hideBorder: true,
              expand: true,
              borderRadius: BorderRadius.circular(1),
            ),
            // child: Container(color: Color(0xFFFFFFFF)),
          ),
          border,
        ]);

        if (after > 0) {
          flexChildren.add(
            Spacer(flex: after),
          );
        }

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
                left: isVertical ? 1 : _mainAxisButtonSize - 1,
                right: isVertical ? 1 : _mainAxisButtonSize - 1,
                top: isHorizontal ? 1 : _mainAxisButtonSize - 1,
                bottom: isHorizontal ? 1 : _mainAxisButtonSize - 1,
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
