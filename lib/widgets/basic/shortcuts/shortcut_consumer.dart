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

import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
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
  final Function(LogicalKeySet shortcut)? shortcutHandler;

  /// This function will be called when this consumer receives a shortcut.
  final bool Function(KeyEvent event)? rawKeyHandler;

  /// If true, this handler will always be called when a shortcut is triggered.
  final bool global;

  const ShortcutConsumer({
    super.key,
    required this.id,
    this.child,
    this.shortcutHandler,
    this.rawKeyHandler,
    this.global = false,
  });

  @override
  State<ShortcutConsumer> createState() => _ShortcutConsumerState();
}

class _ShortcutConsumerState extends State<ShortcutConsumer> {
  var registered = false;
  ShortcutProviderController? controller;

  String getID() {
    final project = Provider.of<ProjectModel>(context, listen: false);
    return '${project.id}-${widget.id}';
  }

  late String id;

  void register() {
    id = getID();
    controller!.registerRawKeyHandler(
        id: id,
        handler: (event) {
          return widget.rawKeyHandler?.call(event) ?? false;
        });
    controller!.registerShortcutHandler(
      id: id,
      global: widget.global,
      handler: (event) {
        final project = Provider.of<ProjectModel>(context, listen: false);

        // Don't process shortcuts if this tab is not selected
        if (project.id != AnthemStore.instance.activeProjectID) return;

        onShortcut(event);
      },
    );
    registered = true;
  }

  void onShortcut(LogicalKeySet shortcut) {
    widget.shortcutHandler?.call(shortcut);
  }

  @override
  Widget build(BuildContext context) {
    controller ??= Provider.of<ShortcutProviderController>(context);

    if (!registered) register();

    // If this is a global handler, we don't want to steal focus on mouse down.
    if (widget.global) return widget.child ?? const SizedBox();

    return Listener(
      onPointerDown: (e) {
        controller!.setActiveConsumer(id);
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller!.unregisterRawKeyHandler(id);
    controller!.unregisterShortcutHandler(id);
    super.dispose();
  }
}
