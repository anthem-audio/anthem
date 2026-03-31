/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:math';

import 'package:flutter/widgets.dart';

enum _HorizontalDirection { right, left }

enum _VerticalDirection { down, up }

enum _VerticalAttachment { aroundAnchor, alignAnchorTop }

/// Positions a popup menu inside the screen overlay while keeping it visible.
///
/// The [anchorRect] describes the trigger area in overlay/global coordinates:
/// - For point anchors (context menus), use a zero-size rect.
/// - For anchored elements (submenus), pass the trigger item's bounds.
///
/// The widget prefers the requested horizontal/vertical directions, but will
/// flip to the opposite side if needed and finally clamp to viewport bounds.
class MenuPositioned extends StatelessWidget {
  /// Anchor in overlay/global coordinates.
  final Rect anchorRect;

  /// Horizontal gap from [anchorRect] to the menu.
  final double horizontalGap;

  /// Vertical gap from [anchorRect] to the menu.
  final double verticalGap;

  /// Preferred horizontal opening direction.
  final bool preferRight;

  /// Preferred vertical opening direction.
  final bool preferDown;

  /// If true, align menu top to anchor top; otherwise place above/below anchor.
  final bool alignTopToAnchor;

  /// Extra inset from the viewport edges.
  final double screenPadding;

  /// The menu content.
  final Widget child;

  const MenuPositioned({
    super.key,
    required this.anchorRect,
    required this.child,
    this.horizontalGap = 0,
    this.verticalGap = 0,
    this.preferRight = true,
    this.preferDown = true,
    this.alignTopToAnchor = false,
    this.screenPadding = 6,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final mediaPadding = mediaQuery?.padding ?? EdgeInsets.zero;

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _MenuPositionDelegate(
          anchorRect: anchorRect,
          horizontalGap: horizontalGap,
          verticalGap: verticalGap,
          horizontalDirection: preferRight
              ? _HorizontalDirection.right
              : _HorizontalDirection.left,
          verticalDirection: preferDown
              ? _VerticalDirection.down
              : _VerticalDirection.up,
          verticalAttachment: alignTopToAnchor
              ? _VerticalAttachment.alignAnchorTop
              : _VerticalAttachment.aroundAnchor,
          mediaPadding: mediaPadding,
          screenPadding: screenPadding,
        ),
        child: child,
      ),
    );
  }
}

class _MenuPositionDelegate extends SingleChildLayoutDelegate {
  final Rect anchorRect;
  final double horizontalGap;
  final double verticalGap;
  final _HorizontalDirection horizontalDirection;
  final _VerticalDirection verticalDirection;
  final _VerticalAttachment verticalAttachment;
  final EdgeInsets mediaPadding;
  final double screenPadding;

  const _MenuPositionDelegate({
    required this.anchorRect,
    required this.horizontalGap,
    required this.verticalGap,
    required this.horizontalDirection,
    required this.verticalDirection,
    required this.verticalAttachment,
    required this.mediaPadding,
    required this.screenPadding,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = max(
      0.0,
      constraints.maxWidth - mediaPadding.horizontal - screenPadding * 2,
    );
    final maxHeight = max(
      0.0,
      constraints.maxHeight - mediaPadding.vertical - screenPadding * 2,
    );

    return BoxConstraints.loose(Size(maxWidth, maxHeight));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final boundsLeft = mediaPadding.left + screenPadding;
    final boundsTop = mediaPadding.top + screenPadding;
    final boundsRight = size.width - mediaPadding.right - screenPadding;
    final boundsBottom = size.height - mediaPadding.bottom - screenPadding;

    final minX = boundsLeft;
    final minY = boundsTop;
    final maxX = max(minX, boundsRight - childSize.width);
    final maxY = max(minY, boundsBottom - childSize.height);

    final roomRight = boundsRight - (anchorRect.right + horizontalGap);
    final roomLeft = (anchorRect.left - horizontalGap) - boundsLeft;
    final xRight = anchorRect.right + horizontalGap;
    final xLeft = anchorRect.left - horizontalGap - childSize.width;
    final x = _pickAndClampAxis(
      preferred: switch (horizontalDirection) {
        .right => xRight,
        .left => xLeft,
      },
      fallback: switch (horizontalDirection) {
        .right => xLeft,
        .left => xRight,
      },
      preferredRoom: switch (horizontalDirection) {
        .right => roomRight,
        .left => roomLeft,
      },
      fallbackRoom: switch (horizontalDirection) {
        .right => roomLeft,
        .left => roomRight,
      },
      min: minX,
      max: maxX,
    );

    final y = switch (verticalAttachment) {
      _VerticalAttachment.alignAnchorTop =>
        (anchorRect.top + verticalGap).clamp(minY, maxY),
      _VerticalAttachment.aroundAnchor => _pickAndClampAroundAnchorY(
        anchorRect: anchorRect,
        verticalGap: verticalGap,
        verticalDirection: verticalDirection,
        minY: minY,
        maxY: maxY,
        boundsTop: boundsTop,
        boundsBottom: boundsBottom,
        childHeight: childSize.height,
      ),
    };

    return Offset(x, y.toDouble());
  }

  @override
  bool shouldRelayout(covariant _MenuPositionDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        horizontalGap != oldDelegate.horizontalGap ||
        verticalGap != oldDelegate.verticalGap ||
        horizontalDirection != oldDelegate.horizontalDirection ||
        verticalDirection != oldDelegate.verticalDirection ||
        verticalAttachment != oldDelegate.verticalAttachment ||
        mediaPadding != oldDelegate.mediaPadding ||
        screenPadding != oldDelegate.screenPadding;
  }
}

/// Picks a vertical position around the anchor (above or below), then clamps.
double _pickAndClampAroundAnchorY({
  required Rect anchorRect,
  required double verticalGap,
  required _VerticalDirection verticalDirection,
  required double minY,
  required double maxY,
  required double boundsTop,
  required double boundsBottom,
  required double childHeight,
}) {
  final roomDown = boundsBottom - (anchorRect.bottom + verticalGap);
  final roomUp = (anchorRect.top - verticalGap) - boundsTop;
  final yDown = anchorRect.bottom + verticalGap;
  final yUp = anchorRect.top - verticalGap - childHeight;

  return _pickAndClampAxis(
    preferred: verticalDirection == _VerticalDirection.down ? yDown : yUp,
    fallback: verticalDirection == _VerticalDirection.down ? yUp : yDown,
    preferredRoom: verticalDirection == _VerticalDirection.down
        ? roomDown
        : roomUp,
    fallbackRoom: verticalDirection == _VerticalDirection.down
        ? roomUp
        : roomDown,
    min: minY,
    max: maxY,
  );
}

/// Picks preferred or fallback axis value based on fit/available room, then
/// clamps the result into [min]..[max].
double _pickAndClampAxis({
  required double preferred,
  required double fallback,
  required double preferredRoom,
  required double fallbackRoom,
  required double min,
  required double max,
}) {
  final preferredFits = preferred >= min && preferred <= max;
  final fallbackFits = fallback >= min && fallback <= max;

  if (preferredFits) {
    return preferred.clamp(min, max);
  }

  if (fallbackFits) {
    return fallback.clamp(min, max);
  }

  if (preferredRoom >= fallbackRoom) {
    return preferred.clamp(min, max);
  }

  return fallback.clamp(min, max);
}
