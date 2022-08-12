/*
  Copyright (C) 2021 Joshua Wade

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

enum ScrollbarDirection { horizontal, vertical }

class Scrollbar extends StatefulWidget {
  final ScrollController controller;
  final ScrollbarDirection direction;
  final double crossAxisSize;

  const Scrollbar({
    Key? key,
    required this.controller,
    required this.direction,
    required this.crossAxisSize,
  }) : super(key: key);

  @override
  State<Scrollbar> createState() => _ScrollbarState();
}

class _ScrollbarState extends State<Scrollbar> {
  double _localStartPos = -1;
  double _scrollAreaStartPos = -1;

  int before = 0;
  int inside = 1;
  int after = 0;

  void _controllerListener() {
    final controller = widget.controller;

    setState(() {
      before = ((controller.position.extentBefore) * 4).round();
      inside = (controller.position.extentInside * 4).round();
      after = ((controller.position.extentAfter) * 4).round();
    });
  }

  @override
  void initState() {
    widget.controller.addListener(_controllerListener);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerListener);
    super.dispose();
  }

  bool _isHorizontal() {
    return widget.direction == ScrollbarDirection.horizontal;
  }

  bool _isVertical() {
    return widget.direction == ScrollbarDirection.vertical;
  }

  void _handleDown(double pos, double containerMainAxisLength) {
    _localStartPos = pos;
    _scrollAreaStartPos = widget.controller.position.pixels;
  }

  void _handleMove(double pos, double containerMainAxisLength) {
    final delta = pos - _localStartPos;
    final normalizedThumbSize = inside / (before + inside + after);
    final normalizedDelta = delta / containerMainAxisLength;
    final scrollAreaStart = widget.controller.position.minScrollExtent;
    final scrollAreaEnd = widget.controller.position.maxScrollExtent;
    final scrollAreaSize = scrollAreaEnd - scrollAreaStart;
    final targetPos =
        normalizedDelta * (scrollAreaSize * (1 / (1 - normalizedThumbSize))) +
            _scrollAreaStartPos +
            scrollAreaStart;
    widget.controller.jumpTo(targetPos.clamp(scrollAreaStart, scrollAreaEnd));
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = _isVertical();
    final isHorizontal = _isHorizontal();

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
        child: const Button(
          hideBorder: true,
          expand: true,
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

    return Container(
      width: isVertical ? widget.crossAxisSize : null,
      height: isHorizontal ? widget.crossAxisSize : null,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.panel.border,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
      child: Stack(
        children: [
          // Start button
          Positioned(
            left: 0,
            top: 0,
            right: isVertical ? 0 : null,
            bottom: isHorizontal ? 0 : null,
            child: Button(
              width: isHorizontal ? widget.crossAxisSize : null,
              height: isVertical ? widget.crossAxisSize : null,
              hideBorder: true,
            ),
          ),

          // Start button border
          Positioned(
            left: isHorizontal ? widget.crossAxisSize : 0,
            right: isHorizontal ? null : 0,
            top: isVertical ? widget.crossAxisSize : 0,
            bottom: isVertical ? null : 0,
            child: border,
          ),

          // End button
          Positioned(
            left: isVertical ? 0 : null,
            top: isHorizontal ? 0 : null,
            right: 0,
            bottom: 0,
            child: Button(
              width: isHorizontal ? widget.crossAxisSize : null,
              height: isVertical ? widget.crossAxisSize : null,
              hideBorder: true,
            ),
          ),

          // End button border
          Positioned(
            left: isHorizontal ? null : 0,
            right: isHorizontal ? widget.crossAxisSize : 0,
            top: isVertical ? null : 0,
            bottom: isVertical ? widget.crossAxisSize : 0,
            child: border,
          ),

          // Scrollbar track with handle
          Positioned(
            left: isVertical ? 0 : widget.crossAxisSize,
            right: isVertical ? 0 : widget.crossAxisSize,
            top: isHorizontal ? 0 : widget.crossAxisSize,
            bottom: isHorizontal ? 0 : widget.crossAxisSize,
            child: GestureDetector(
              onVerticalDragDown: (details) {
                if (!_isVertical()) return;
                _handleDown(
                    details.localPosition.dy, context.size?.height ?? 1);
              },
              onVerticalDragUpdate: (details) {
                if (!_isVertical()) return;
                _handleMove(
                    details.localPosition.dy, context.size?.height ?? 1);
              },
              onHorizontalDragDown: (details) {
                if (!_isHorizontal()) return;
                _handleDown(details.localPosition.dx, context.size?.width ?? 1);
              },
              onHorizontalDragUpdate: (details) {
                if (!_isHorizontal()) return;
                _handleMove(details.localPosition.dx, context.size?.width ?? 1);
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
  }
}
