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

import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Provides a way for Anthem's editors to listen for shortcuts.
class AnthemShortcuts extends StatefulWidget {
  final String id;
  final Widget? child;
  final Function(LogicalKeySet shortcut)? handler;

  const AnthemShortcuts(
      {super.key, required this.id, this.child, this.handler});

  @override
  State<AnthemShortcuts> createState() => _AnthemShortcutsState();
}

class _AnthemShortcutsState extends State<AnthemShortcuts> {
  var registered = false;
  ShortcutProviderController? controller;

  void register() {
    controller!.register(id: widget.id, handler: onShortcut);
    // TODO this should be triggered by mouse activity in the editor, not automatically on register
    controller!.focus(widget.id);
    registered = true;
  }

  void onShortcut(LogicalKeySet shortcut) {
    widget.handler?.call(shortcut);
  }

  @override
  Widget build(BuildContext context) {
    controller ??= Provider.of<ShortcutProviderController>(context);

    if (!registered) register();

    return widget.child ?? const SizedBox();
  }

  @override
  void dispose() {
    controller!.unregister(widget.id);
    super.dispose();
  }
}
