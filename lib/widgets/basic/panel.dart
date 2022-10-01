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

enum PanelOrientation { left, top, right, bottom }

bool _isLeftOrRight(PanelOrientation orientation) {
  return orientation == PanelOrientation.left ||
      orientation == PanelOrientation.right;
}

bool _isPanelFirst(PanelOrientation orientation) {
  return orientation == PanelOrientation.left ||
      orientation == PanelOrientation.top;
}

class Panel extends StatefulWidget {
  final Widget panelContent;
  final Widget child;
  final PanelOrientation orientation;
  final bool? hidden;
  final double? panelStartSize;
  final double? separatorSize;

  const Panel({
    Key? key,
    required this.panelContent,
    required this.child,
    required this.orientation,
    this.hidden,
    this.panelStartSize,
    this.separatorSize,
  }) : super(key: key);

  @override
  State<Panel> createState() => _PanelState();
}

const defaultPanelSize = 300.0;

class _PanelState extends State<Panel> {
  double panelSize = -1;

  // event variables, not used during render
  bool mouseDown = false;
  double startPos = -1;
  double startSize = -1;

  @override
  Widget build(BuildContext context) {
    if (panelSize < 0) {
      panelSize = widget.panelStartSize ?? defaultPanelSize;
    }

    final horizontal = _isLeftOrRight(widget.orientation);
    final panelFirst = _isPanelFirst(widget.orientation);

    final panelHidden = widget.hidden ?? false;

    final panelHugLeft = !horizontal || panelFirst;
    final panelHugRight = !horizontal || !panelFirst;
    final panelHugTop = horizontal || panelFirst;
    final panelHugBottom = horizontal || !panelFirst;

    var contentHugLeft = !horizontal || !panelFirst;
    var contentHugRight = !horizontal || panelFirst;
    var contentHugTop = horizontal || !panelFirst;
    var contentHugBottom = horizontal || panelFirst;

    contentHugLeft |= panelHidden;
    contentHugRight |= panelHidden;
    contentHugTop |= panelHidden;
    contentHugBottom |= panelHidden;

    final separatorSize = widget.separatorSize ?? 3.0;
    const handleSize = 10.0;

    var handleLeft =
        panelHugLeft ? panelSize - handleSize / 2 + separatorSize / 2 : null;
    var handleRight =
        panelHugRight ? panelSize - handleSize / 2 + separatorSize / 2 : null;
    var handleTop =
        panelHugTop ? panelSize - handleSize / 2 + separatorSize / 2 : null;
    var handleBottom =
        panelHugBottom ? panelSize - handleSize / 2 + separatorSize / 2 : null;

    if (horizontal) {
      handleTop = 0;
      handleBottom = 0;
    } else {
      handleLeft = 0;
      handleRight = 0;
    }

    return Stack(
      children: [
        // Panel
        Positioned(
          left: panelHugLeft ? 0 : null,
          right: panelHugRight ? 0 : null,
          top: panelHugTop ? 0 : null,
          bottom: panelHugBottom ? 0 : null,
          child: Visibility(
            maintainState: true,
            visible: !panelHidden,
            child: SizedBox(
              width: horizontal ? panelSize : null,
              height: !horizontal ? panelSize : null,
              child: widget.panelContent,
            ),
          ),
        ),

        // Child
        Positioned(
          left: contentHugLeft ? 0 : panelSize + separatorSize,
          right: contentHugRight ? 0 : panelSize + separatorSize,
          top: contentHugTop ? 0 : panelSize + separatorSize,
          bottom: contentHugBottom ? 0 : panelSize + separatorSize,
          child: widget.child,
        ),

        // Draggable separator
        Visibility(
          visible: !panelHidden,
          child: Positioned(
            left: handleLeft,
            right: handleRight,
            top: handleTop,
            bottom: handleBottom,
            child: MouseRegion(
              cursor: horizontal
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown,
              opaque: false,
              child: Listener(
                onPointerDown: (e) {
                  mouseDown = true;
                  startPos = (horizontal ? e.position.dx : e.position.dy);
                  startSize = panelSize;
                },
                onPointerUp: (e) {
                  mouseDown = false;
                },
                onPointerMove: (e) {
                  final delta =
                      ((horizontal ? e.position.dx : e.position.dy) - startPos) *
                          (panelFirst ? 1 : -1);
                  setState(() {
                    panelSize = (startSize + delta).clamp(0, double.infinity);
                  });
                },
                child: Container(
                  width: horizontal ? handleSize : null,
                  height: !horizontal ? handleSize : null,
                  // this is not clickable unless it has a color and I have no idea why
                  color: const Color(0x00FFFFFF),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
