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

/// Draws the left divider inside the editor.
///
/// When scrolled all the way to the left, editors draw a grid line at the first
/// pixel. If the pixel immediately to the left of that is also a border, it
/// looks odd.
///
/// As a solution, we draw the left border of the editor inside the editor area,
/// above the content (and below the playhead). This makes everything look
/// better when scrolled all the way to the left.
class EditorLeftEdgeBorder extends StatelessWidget {
  const EditorLeftEdgeBorder({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _EditorLeftEdgeBorderPainter()),
    );
  }
}

class _EditorLeftEdgeBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AnthemTheme.panel.border
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, 1, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _EditorLeftEdgeBorderPainter oldDelegate) {
    return false;
  }

  @override
  bool shouldRebuildSemantics(
    covariant _EditorLeftEdgeBorderPainter oldDelegate,
  ) {
    return false;
  }
}
