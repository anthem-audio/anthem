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

/// Provides a way for Anthem's editors to listen for shortcuts. This widget
/// renders a [Listener] that captures mouse events and tells the
/// nearest [ShortcutProvider] when it is clicked on. This provides a crude way
/// to track which editor is active, so that only the active editor receives
/// keyboard shortcuts.
class ShortcutConsumer extends StatefulWidget {
  /// The ID of this consumer. Must be unique within a project (i.e. you cannot
  /// have two widgets with a key of `piano-roll` within the same tab).
  final String id;

  final Widget? child;

  /// This function will be called when this consumer receives a shortcut.
  final Function(LogicalKeySet shortcut)? handler;

  const ShortcutConsumer(
      {super.key, required this.id, this.child, this.handler});

  @override
  State<ShortcutConsumer> createState() => _ShortcutConsumerState();
}

class _ShortcutConsumerState extends State<ShortcutConsumer> {
  var registered = false;
  ShortcutProviderController? controller;

  void register() {
    controller!.register(id: widget.id, handler: onShortcut);
    registered = true;
  }

  void onShortcut(LogicalKeySet shortcut) {
    widget.handler?.call(shortcut);
  }

  @override
  Widget build(BuildContext context) {
    controller ??= Provider.of<ShortcutProviderController>(context);

    if (!registered) register();

    return Listener(
      onPointerDown: (e) {
        controller!.focus(widget.id);
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller!.unregister(widget.id);
    super.dispose();
  }
}
