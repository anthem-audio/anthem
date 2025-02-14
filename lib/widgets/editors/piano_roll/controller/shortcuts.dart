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

part of 'piano_roll_controller.dart';

mixin _PianoRollShortcutsMixin on _PianoRollController {
  ShortcutBehaviors shortcutManager = ShortcutBehaviors();

  void registerShortcuts() {
    // Delete
    shortcutManager.register(LogicalKeySet(LogicalKeyboardKey.delete), () {
      deleteSelected();
    });

    // Ctrl + A
    shortcutManager.register(
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA),
      () {
        selectAll();
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
}
