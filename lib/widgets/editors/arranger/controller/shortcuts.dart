/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

part of 'arranger_controller.dart';

mixin _ArrangerShortcutsMixin on _ArrangerController {
  ShortcutBehaviors shortcutManager = ShortcutBehaviors();

  bool onRawKeyEvent(KeyEvent event) {
    if (!_isArrangerPanelActive()) {
      return false;
    }

    if (event is KeyDownEvent && event.logicalKey == .escape) {
      stateMachine.cancelInteraction(trigger: .escapeKey);
      return false;
    }

    final modifier = _getModifierKey(event.logicalKey);
    if (modifier == null) {
      return false;
    }

    if (event is KeyDownEvent) {
      stateMachine.modifierPressed(modifier);
    } else if (event is KeyUpEvent) {
      stateMachine.modifierReleased(modifier);
    }

    // Let other raw handlers and shortcuts continue to process this event.
    return false;
  }

  void registerShortcuts() {
    // Delete
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.delete), () {
      deleteSelectedClips();
    });

    // Ctrl + A
    shortcutManager.register(
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA),
      () {
        selectAllClips();
      },
    );

    // P - pencil
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.keyP), () {
      viewModel.tool = EditorTool.pencil;
    });

    // B - brush - we don't have a brush, but this is on the left hand so it's nicer
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.keyB), () {
      viewModel.tool = EditorTool.pencil;
    });

    // E - select
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.keyE), () {
      viewModel.tool = EditorTool.select;
    });

    // D - erase
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.keyD), () {
      viewModel.tool = EditorTool.eraser;
    });

    // C - cut
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.keyC), () {
      viewModel.tool = EditorTool.cut;
    });
  }

  void onShortcut(LogicalKeySet shortcut) {
    shortcutManager.handleShortcut(shortcut);
  }

  bool _isArrangerPanelActive() {
    final projectViewModel = ServiceRegistry.forProject(
      viewModel.projectId,
    ).projectViewModel;

    return projectViewModel.activePanel == PanelKind.arranger;
  }

  ArrangerModifierKey? _getModifierKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      return ArrangerModifierKey.ctrl;
    }

    if (key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      return ArrangerModifierKey.alt;
    }

    if (key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      return ArrangerModifierKey.shift;
    }

    return null;
  }
}
