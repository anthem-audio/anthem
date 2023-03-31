/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'helpers/time_helpers.dart';
import 'helpers/types.dart';

/// Abstracts scroll events for editors
class EditorScrollManager extends StatefulWidget {
  final Widget? child;
  final TimeRange timeView;
  final void Function(int pixelDelta)? onVerticalScrollChange;

  const EditorScrollManager({
    Key? key,
    this.child,
    required this.timeView,
    this.onVerticalScrollChange,
  }) : super(key: key);

  @override
  State<EditorScrollManager> createState() => _EditorScrollManagerState();
}

class _EditorScrollManagerState extends State<EditorScrollManager> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          handleScroll(event);
        }
      },
      child: widget.child,
    );
  }

  handleScroll(PointerScrollEvent e) {
    final delta = e.scrollDelta.dy;

    final modifiers = Provider.of<KeyboardModifiers>(context, listen: false);
    final contentRenderBox = context.findRenderObject() as RenderBox;

    // Zoom
    if (modifiers.ctrl) {
      final pointerPos = contentRenderBox.globalToLocal(e.position);

      zoomTimeView(
        timeView: widget.timeView,
        delta: delta,
        mouseX: pointerPos.dx,
        editorWidth: contentRenderBox.size.width,
      );

      return;
    }

    // Horizontal scroll
    if (modifiers.shift) {
      // We need to scroll by the same speed in pixels, regardless of how
      // zoomed in we are. Since our current scroll position is in time and not
      // pixels, we use this value to convert between the two.
      final ticksPerPixel = widget.timeView.width / contentRenderBox.size.width;

      const scrollAmountInPixels = 100;

      var scrollAmountInTicks =
          delta * 0.01 * scrollAmountInPixels * ticksPerPixel;

      if (widget.timeView.start + scrollAmountInTicks < 0) {
        scrollAmountInTicks = -widget.timeView.start;
      }

      widget.timeView.start += scrollAmountInTicks;
      widget.timeView.end += scrollAmountInTicks;
      return;
    }

    // Vertical scroll

    final scrollAmountInPixels = delta.round();

    widget.onVerticalScrollChange?.call(scrollAmountInPixels);
  }
}
