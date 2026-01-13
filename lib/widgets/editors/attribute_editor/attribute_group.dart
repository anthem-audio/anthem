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
import 'package:anthem/widgets/basic/icon.dart';
import 'package:flutter/widgets.dart';

/// Defines a group of attributes for the attribute editor.
///
/// Contains a title, some arbitrary content, and the ability to expand and
/// collapse.
class AttributeGroup extends StatefulWidget {
  final String title;
  final Widget? child;

  const AttributeGroup({super.key, required this.title, this.child});

  @override
  State<AttributeGroup> createState() => _AttributeGroupState();
}

class _AttributeGroupState extends State<AttributeGroup>
    with SingleTickerProviderStateMixin {
  bool headerHovered = false;
  bool expanded = true;

  late Animation<double> heightAnimation;
  late AnimationController heightAnimationController;

  @override
  void initState() {
    super.initState();

    heightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    heightAnimation = CurvedAnimation(
      parent: heightAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    heightAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = headerHovered
        ? AnthemTheme.text.accent
        : AnthemTheme.text.main;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (e) {
            setState(() {
              headerHovered = true;
            });
          },
          onExit: (e) {
            setState(() {
              headerHovered = false;
            });
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                expanded = !expanded;
              });
              if (expanded) {
                heightAnimationController.forward();
              } else {
                heightAnimationController.reverse();
              }
            },
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: AnthemTheme.panel.background,
                border: Border(
                  bottom: .new(color: AnthemTheme.panel.border, width: 1),
                ),
              ),
              child: Padding(
                padding: const .symmetric(horizontal: 7),
                child: Row(
                  crossAxisAlignment: .center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: .new(
                          fontWeight: .w500,
                          fontSize: 12,
                          height: 1,
                          color: color,
                          overflow: .ellipsis,
                        ),
                        // This helps with vertical centering, at least for English
                        // text. To see what this does, wrap the Text() widget with a
                        // container, add a background color, and toggle this on and
                        // off.
                        textHeightBehavior: .new(
                          applyHeightToLastDescent: false,
                        ),
                      ),
                    ),
                    RotatedBox(
                      quarterTurns: expanded ? 0 : 2,
                      child: SvgIcon(icon: Icons.arrowDownThin, color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: heightAnimation,
          axis: .vertical,
          axisAlignment: -1,
          child: Container(
            // SizeTransition contains Align, which un-does the column cross
            // axis expand, so we need to force a horizontal expansion here
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: .new(width: 2, color: AnthemTheme.panel.border),
              ),
              color: AnthemTheme.panel.main,
            ),
            padding: EdgeInsets.all(4),
            child: widget.child ?? SizedBox(height: 100),
          ),
        ),
      ],
    );
  }
}
