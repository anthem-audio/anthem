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

import 'package:anthem/logic/service_registry.dart';
import 'package:flutter/widgets.dart';

enum PanelOrientation { left, top, right, bottom }

enum PanelSizeBehavior { pixels, flex }

bool _isLeftOrRight(PanelOrientation orientation) {
  return orientation == PanelOrientation.left ||
      orientation == PanelOrientation.right;
}

bool _isPanelFirst(PanelOrientation orientation) {
  return orientation == PanelOrientation.left ||
      orientation == PanelOrientation.top;
}

// Tracks if a resize is already active. We use this to enable logic that
// prevents multiple resize handles from triggering resize operations at once,
// in the case that resize indicators are overlapping.
bool isResizeActive = false;

class Panel extends StatefulWidget {
  final Widget panelContent;
  final Widget child;
  final PanelOrientation orientation;
  final bool? hidden;
  final double? panelStartSize;
  final double? separatorSize;
  final PanelSizeBehavior sizeBehavior;

  final double panelMinSize;
  final double panelMaxSize;
  final double contentMinSize;
  final double contentMaxSize;

  const Panel({
    super.key,
    required this.panelContent,
    required this.child,
    required this.orientation,
    this.sizeBehavior = PanelSizeBehavior.flex,
    this.hidden,
    this.panelStartSize,
    this.separatorSize,
    this.panelMinSize = 0,
    this.panelMaxSize = double.infinity,
    this.contentMinSize = 0,
    this.contentMaxSize = double.infinity,
  });

  @override
  State<Panel> createState() => _PanelState();
}

const defaultPanelSize = 300.0;

class _PanelState extends State<Panel> {
  double flexPanelSize = -1;
  double pixelPanelSize = -1;

  // event variables, not used during render
  bool resizeActive = false;
  double startPos = -1;
  double startSize = -1;

  MouseCursor cursorFromBuild = MouseCursor.defer;

  void onResizePointerDown(PointerDownEvent e, double panelSize) {
    if (isResizeActive) return;

    isResizeActive = true;
    resizeActive = true;

    final horizontal = _isLeftOrRight(widget.orientation);
    startPos = (horizontal ? e.position.dx : e.position.dy);
    startSize = panelSize;

    ServiceRegistry.mainWindowController!.setCursorOverride(cursorFromBuild);
  }

  void onResizePointerUp(PointerUpEvent e) {
    resizeActive = false;
    isResizeActive = false;

    ServiceRegistry.mainWindowController!.clearCursorOverride();
  }

  void onResizePointerCancel(PointerCancelEvent e) {
    resizeActive = false;
    isResizeActive = false;
  }

  void onResizePointerMove(
    PointerMoveEvent e,
    BoxConstraints constraints,
    double mainAxisSize,
  ) {
    if (!resizeActive) return;

    final isHorizontal = _isLeftOrRight(widget.orientation);
    final isPanelFirst = _isPanelFirst(widget.orientation);

    final delta =
        ((isHorizontal ? e.position.dx : e.position.dy) - startPos) *
        (isPanelFirst ? 1 : -1);
    setState(() {
      final pixelPanelSizeRaw = startSize + delta;
      final pixelContentSizeRaw =
          (isHorizontal ? constraints.maxWidth : constraints.maxHeight) -
          pixelPanelSizeRaw;

      final pixelContentSizeClamped = pixelContentSizeRaw.clamp(
        widget.contentMinSize,
        widget.contentMaxSize,
      );

      pixelPanelSize =
          (pixelPanelSizeRaw + (pixelContentSizeRaw - pixelContentSizeClamped))
              .clamp(widget.panelMinSize, widget.panelMaxSize);

      flexPanelSize = pixelPanelSize / mainAxisSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = _isLeftOrRight(widget.orientation);

        final mainAxisSize = (isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight);

        cursorFromBuild = isHorizontal
            ? SystemMouseCursors.resizeLeftRight
            : SystemMouseCursors.resizeUpDown;

        if (pixelPanelSize < 0) {
          pixelPanelSize = widget.panelStartSize ?? defaultPanelSize;
        }

        if (flexPanelSize < 0) {
          if (widget.panelStartSize != null) {
            flexPanelSize = widget.panelStartSize! / mainAxisSize;
          } else {
            flexPanelSize = 0.5;
          }
        }

        var panelSize = widget.sizeBehavior == PanelSizeBehavior.flex
            ? flexPanelSize * mainAxisSize
            : pixelPanelSize;

        // Make sure we're snapping to a pixel boundary
        final queryData = MediaQuery.of(context);
        panelSize *= queryData.devicePixelRatio;
        panelSize = panelSize.round().toDouble();
        panelSize /= queryData.devicePixelRatio;

        final isPanelFirst = _isPanelFirst(widget.orientation);

        final isPanelHidden = widget.hidden ?? false;

        final panelHugLeft = !isHorizontal || isPanelFirst;
        final panelHugRight = !isHorizontal || !isPanelFirst;
        final panelHugTop = isHorizontal || isPanelFirst;
        final panelHugBottom = isHorizontal || !isPanelFirst;

        var contentHugLeft = !isHorizontal || !isPanelFirst;
        var contentHugRight = !isHorizontal || isPanelFirst;
        var contentHugTop = isHorizontal || !isPanelFirst;
        var contentHugBottom = isHorizontal || isPanelFirst;

        contentHugLeft |= isPanelHidden;
        contentHugRight |= isPanelHidden;
        contentHugTop |= isPanelHidden;
        contentHugBottom |= isPanelHidden;

        final separatorSize = widget.separatorSize ?? 1.0;
        const handleSize = 10.0;

        var handleLeft = panelHugLeft
            ? panelSize - handleSize / 2 + separatorSize / 2
            : null;
        var handleRight = panelHugRight
            ? panelSize - handleSize / 2 + separatorSize / 2
            : null;
        var handleTop = panelHugTop
            ? panelSize - handleSize / 2 + separatorSize / 2
            : null;
        var handleBottom = panelHugBottom
            ? panelSize - handleSize / 2 + separatorSize / 2
            : null;

        if (isHorizontal) {
          handleTop = 0;
          handleBottom = 0;
        } else {
          handleLeft = 0;
          handleRight = 0;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Panel
            Positioned(
              left: panelHugLeft ? 0 : null,
              right: panelHugRight ? 0 : null,
              top: panelHugTop ? 0 : null,
              bottom: panelHugBottom ? 0 : null,
              child: Visibility(
                maintainState: true,
                visible: !isPanelHidden,
                child: SizedBox(
                  width: isHorizontal ? panelSize : null,
                  height: !isHorizontal ? panelSize : null,
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
            if (!isPanelHidden)
              Positioned(
                left: handleLeft,
                right: handleRight,
                top: handleTop,
                bottom: handleBottom,
                child: MouseRegion(
                  cursor: cursorFromBuild,
                  opaque: false,
                  child: Listener(
                    onPointerDown: (e) => onResizePointerDown(e, panelSize),
                    onPointerUp: onResizePointerUp,
                    onPointerCancel: onResizePointerCancel,
                    onPointerMove: (e) =>
                        onResizePointerMove(e, constraints, mainAxisSize),
                    child: Container(
                      width: isHorizontal ? handleSize : null,
                      height: !isHorizontal ? handleSize : null,
                      // this is not clickable unless it has a color and I have no idea why
                      color: const Color(0x00FFFFFF),
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
