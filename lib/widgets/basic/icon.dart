/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

class IconDef {
  final String path;

  const IconDef(this.path);
}

class Icons {
  static IconDef add = const IconDef('assets/icons/scrollbar/add.svg');
  static IconDef anthem = const IconDef('assets/icons/main/anthem.svg');
  static IconDef arrowDown =
      const IconDef('assets/icons/misc/dropdown_arrow___down.svg');
  static IconDef audio = const IconDef('assets/icons/audio.svg');
  static IconDef automation = const IconDef('assets/icons/automation.svg');
  static IconDef automationMatrixPanel =
      const IconDef('assets/icons/bottom_bar/automation_panel.svg');
  static IconDef browserPanel =
      const IconDef('assets/icons/bottom_bar/browser_panel.svg');
  static IconDef channelRack =
      const IconDef('assets/icons/bottom_bar/instruments_effects_panel.svg');
  static IconDef close = const IconDef('assets/icons/small/close.svg');
  static IconDef detailEditor =
      const IconDef('assets/icons/bottom_bar/detail_editor.svg');
  static IconDef hamburger = const IconDef('assets/icons/misc/hamburgner.svg');
  static IconDef file = const IconDef('assets/icons/file.svg');
  static IconDef kebab = const IconDef('assets/icons/misc.svg');
  static IconDef maximize = const IconDef('assets/icons/small/maximize.svg');
  static IconDef midi = const IconDef('assets/icons/midi.svg');
  static IconDef minimize = const IconDef('assets/icons/small/minimize.svg');
  static IconDef mixer = const IconDef('assets/icons/bottom_bar/mixer.svg');
  static IconDef mute = const IconDef('assets/icons/power.svg');
  static IconDef patternEditor =
      const IconDef('assets/icons/bottom_bar/pattern_editor.svg');
  static IconDef plugin = const IconDef('assets/icons/plugin.svg');
  static IconDef projectPanel =
      const IconDef('assets/icons/bottom_bar/project_panel_2.svg');
  static IconDef redo = const IconDef('assets/icons/edit/redo.svg');
  static IconDef save = const IconDef('assets/icons/edit/save.svg');
  static IconDef undo = const IconDef('assets/icons/edit/undo.svg');
  static _ScrollbarIcons scrollbar = _ScrollbarIcons();
  static _ToolIcons tools = _ToolIcons();
  static _MainToolbarIcons mainToolbar = _MainToolbarIcons();
}

class _ScrollbarIcons {
  IconDef arrowDown = const IconDef('assets/icons/scrollbar/arrow_down.svg');
  IconDef arrowLeft = const IconDef('assets/icons/scrollbar/arrow_left.svg');
  IconDef arrowRight = const IconDef('assets/icons/scrollbar/arrow_right.svg');
  IconDef arrowUp = const IconDef('assets/icons/scrollbar/arrow_up.svg');
}

class _ToolIcons {
  IconDef cut = const IconDef('assets/icons/tools/cut.svg');
  IconDef erase = const IconDef('assets/icons/tools/erase.svg');
  IconDef pencil = const IconDef('assets/icons/tools/pencil.svg');
  IconDef select = const IconDef('assets/icons/tools/select.svg');
}

class _MainToolbarIcons {
  IconDef typingKeyboardToPianoKeyboard = const IconDef(
      'assets/icons/main_toolbar/typing_keyboard_to_piano_keyboard.svg');
}

class SvgIcon extends StatelessWidget {
  final IconDef icon;
  final Color color;

  const SvgIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      icon.path,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
