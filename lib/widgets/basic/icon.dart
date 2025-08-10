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
  static IconDef add = const IconDef('assets/icons_old/scrollbar/add.svg');
  static IconDef anthem = const IconDef('assets/icons_old/main/anthem.svg');
  static IconDef arrowDown = const IconDef(
    'assets/icons_old/misc/dropdown_arrow___down.svg',
  );
  static IconDef audio = const IconDef('assets/icons_old/audio.svg');
  static IconDef automation = const IconDef('assets/icons_old/automation.svg');
  static IconDef automationMatrixPanel = const IconDef(
    'assets/icons_old/bottom_bar/automation_panel.svg',
  );
  static IconDef browserPanel = const IconDef(
    'assets/icons_old/bottom_bar/browser_panel.svg',
  );
  static IconDef channelRack = const IconDef(
    'assets/icons_old/bottom_bar/instruments_effects_panel.svg',
  );
  static IconDef close = const IconDef('assets/icons_old/small/close.svg');
  static IconDef detailEditor = const IconDef(
    'assets/icons_old/bottom_bar/detail_editor.svg',
  );
  static IconDef hamburger = const IconDef(
    'assets/icons_old/misc/hamburgner.svg',
  );
  static IconDef file = const IconDef('assets/icons_old/file.svg');
  static IconDef kebab = const IconDef('assets/icons_old/misc.svg');
  static IconDef maximize = const IconDef(
    'assets/icons_old/small/maximize.svg',
  );
  static IconDef midi = const IconDef('assets/icons_old/midi.svg');
  static IconDef minimize = const IconDef(
    'assets/icons_old/small/minimize.svg',
  );
  static IconDef mixer = const IconDef('assets/icons_old/bottom_bar/mixer.svg');
  static IconDef mute = const IconDef('assets/icons_old/power.svg');
  static IconDef patternEditor = const IconDef(
    'assets/icons_old/bottom_bar/pattern_editor.svg',
  );
  static IconDef play = const IconDef('assets/icons_old/main_toolbar/play.svg');
  static IconDef plugin = const IconDef('assets/icons_old/plugin.svg');
  static IconDef projectPanel = const IconDef(
    'assets/icons_old/bottom_bar/project_panel_2.svg',
  );
  static IconDef redo = const IconDef('assets/icons_old/edit/redo.svg');
  static IconDef save = const IconDef('assets/icons_old/edit/save.svg');
  static IconDef stop = const IconDef('assets/icons_old/main_toolbar/stop.svg');
  static IconDef undo = const IconDef('assets/icons_old/edit/undo.svg');
  static _ScrollbarIcons scrollbar = _ScrollbarIcons();
  static _ToolIcons tools = _ToolIcons();
  static _MainToolbarIcons mainToolbar = _MainToolbarIcons();
}

class _ScrollbarIcons {
  IconDef arrowDown = const IconDef(
    'assets/icons_old/scrollbar/arrow_down.svg',
  );
  IconDef arrowLeft = const IconDef(
    'assets/icons_old/scrollbar/arrow_left.svg',
  );
  IconDef arrowRight = const IconDef(
    'assets/icons_old/scrollbar/arrow_right.svg',
  );
  IconDef arrowUp = const IconDef('assets/icons_old/scrollbar/arrow_up.svg');
}

class _ToolIcons {
  IconDef cut = const IconDef('assets/icons_old/tools/cut.svg');
  IconDef erase = const IconDef('assets/icons_old/tools/erase.svg');
  IconDef pencil = const IconDef('assets/icons_old/tools/pencil.svg');
  IconDef select = const IconDef('assets/icons_old/tools/select.svg');
}

class _MainToolbarIcons {
  IconDef typingKeyboardToPianoKeyboard = const IconDef(
    'assets/icons_old/main_toolbar/typing_keyboard_to_piano_keyboard.svg',
  );
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
