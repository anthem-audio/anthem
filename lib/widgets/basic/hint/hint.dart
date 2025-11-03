/*
  Copyright (C) 2025 Joshua Wade

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

class Hint extends StatefulWidget {
  final Widget? child;
  final List<HintSection> hint;

  const Hint({super.key, this.child, this.hint = const []});

  @override
  State<Hint> createState() => _HintState();
}

class _HintState extends State<Hint> {
  int? hintId;

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
      child: widget.child,
    );
  }
}
