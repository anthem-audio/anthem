/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:flutter/widgets.dart';

/// On hover, displays the given [hint] in the hint panel.
class Hint extends StatefulWidget {
  final Widget? child;

  /// The hint to be displayed.
  ///
  /// Each hint is a pair, consisting of action (e.g. "click") and hint text
  /// (e.g. "adds a new track"). See [HintSection] for more.
  final List<HintSection> hint;

  /// Controls whether the hint should stay active as long as the mouse was
  /// pressed on the [Hint] widget and has not yet been released.
  final bool overrideWhilePressed;

  const Hint({
    super.key,
    this.child,
    this.hint = const [],
    this.overrideWhilePressed = false,
  });

  @override
  State<Hint> createState() => _HintState();
}

class _HintState extends State<Hint> {
  int? hintId;
  int? overrideHintId;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) {
        if (hintId != null) {
          HintStore.instance.removeHint(hintId!);
          hintId = null;
        }

        if (widget.hint.isNotEmpty) {
          hintId = HintStore.instance.addHint(widget.hint);
        }
      },
      onExit: (e) {
        if (hintId != null) {
          HintStore.instance.removeHint(hintId!);
          hintId = null;
        }
      },
      child: () {
        if (!widget.overrideWhilePressed) {
          return widget.child;
        }

        return Listener(
          onPointerDown: (e) {
            if (overrideHintId != null) {
              HintStore.instance.removeHint(overrideHintId!);
            }

            overrideHintId = HintStore.instance.addHint(widget.hint, true);
          },
          onPointerUp: (e) {
            if (overrideHintId == null) return;

            HintStore.instance.removeHint(overrideHintId!);
            overrideHintId = null;
          },
          child: widget.child,
        );
      }(),
    );
  }
}
