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

import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

const double _buttonGroupOuterRadius = 4;
const double _buttonGroupInnerRadius = _buttonGroupOuterRadius - 1;

class ButtonGroupChildStyle {
  final bool hideBorder;
  final BorderRadius borderRadius;

  const ButtonGroupChildStyle({
    required this.hideBorder,
    required this.borderRadius,
  });
}

class ButtonGroup extends StatelessWidget {
  final Axis axis;
  final List<Widget> children;
  final bool expandChildren;

  const ButtonGroup({
    super.key,
    required this.children,
    this.axis = Axis.horizontal,
    this.expandChildren = false,
  });

  BorderRadius _childBorderRadius(int index, int childCount) {
    if (childCount <= 1) {
      return BorderRadius.circular(_buttonGroupInnerRadius);
    }

    final isFirst = index == 0;
    final isLast = index == childCount - 1;

    if (!isFirst && !isLast) {
      return BorderRadius.zero;
    }

    const radius = Radius.circular(_buttonGroupInnerRadius);

    return switch (axis) {
      Axis.horizontal => switch (isFirst) {
        true => const BorderRadius.horizontal(left: radius),
        false => const BorderRadius.horizontal(right: radius),
      },
      Axis.vertical => switch (isFirst) {
        true => const BorderRadius.vertical(top: radius),
        false => const BorderRadius.vertical(bottom: radius),
      },
    };
  }

  Widget _buildDivider() {
    if (axis == Axis.horizontal) {
      return Container(width: 1, color: AnthemTheme.panel.border);
    }

    return Container(height: 1, color: AnthemTheme.panel.border);
  }

  @override
  Widget build(BuildContext context) {
    final flexChildren = <Widget>[];

    for (var i = 0; i < children.length; i += 1) {
      if (i > 0) {
        flexChildren.add(_buildDivider());
      }

      final child = Provider<ButtonGroupChildStyle>.value(
        value: ButtonGroupChildStyle(
          hideBorder: true,
          borderRadius: _childBorderRadius(i, children.length),
        ),
        child: children[i],
      );

      flexChildren.add(expandChildren ? Expanded(child: child) : child);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AnthemTheme.panel.border),
        borderRadius: BorderRadius.circular(_buttonGroupOuterRadius),
      ),
      child: Flex(
        direction: axis,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: flexChildren,
      ),
    );
  }
}
