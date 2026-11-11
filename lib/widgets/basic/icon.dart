/*
  Copyright (C) 2022 - 2026 Joshua Wade

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
  static IconDef add = const IconDef('assets/icons/general/add.svg');
  static IconDef anthem = const IconDef('assets/icons/brand/anthem.svg');
  static IconDef arrowDown = const IconDef('assets/icons/arrows/dropdown.svg');
  static IconDef audio = const IconDef('assets/icons/track/audio.svg');
  static IconDef automationEditor = const IconDef(
    'assets/icons/panels/automation-editor.svg',
  );
  static IconDef automationMatrixPanel = const IconDef(
    'assets/icons/general/automation.svg',
  );
  static IconDef browserPanel = const IconDef(
    'assets/icons/panels/browser.svg',
  );
  static IconDef deviceRack = const IconDef('assets/icons/panels/devices.svg');
  static IconDef close = const IconDef('assets/icons/window/close-small.svg');
  static IconDef closeWindow = const IconDef('assets/icons/window/close.svg');
  static IconDef pianoRoll = const IconDef('assets/icons/panels/details.svg');
  static IconDef hamburger = const IconDef('assets/icons/general/menu.svg');
  static IconDef file = const IconDef('assets/icons/general/file.svg');
  static IconDef folder = const IconDef('assets/icons/general/folder.svg');
  static IconDef kebab = const IconDef(
    'assets/icons/general/more-vertical.svg',
  );
  static IconDef maximize = const IconDef('assets/icons/window/maximize.svg');
  static IconDef midi = const IconDef('assets/icons/clips/midi.svg');
  static IconDef minimize = const IconDef('assets/icons/window/minimize.svg');
  static IconDef mixer = const IconDef('assets/icons/panels/mixer.svg');
  static IconDef mute = const IconDef('assets/icons/mixer/mute.svg');
  static IconDef openPluginWindow = const IconDef(
    'assets/icons/devices/open-plugin-window.svg',
  );
  static IconDef patternPickerAudio = const IconDef(
    'assets/icons/clips/audio.svg',
  );
  static IconDef patternPickerAutomation = const IconDef(
    'assets/icons/clips/automation.svg',
  );
  static IconDef patternPickerHybrid = const IconDef(
    'assets/icons/clips/hybrid.svg',
  );
  static IconDef patternPickerMidi = const IconDef(
    'assets/icons/clips/midi.svg',
  );
  static IconDef pianoRollStems = const IconDef(
    'assets/icons/piano-roll/control.svg',
  );
  static IconDef play = const IconDef('assets/icons/playback/play.svg');
  static IconDef record = const IconDef('assets/icons/playback/record.svg');
  static IconDef plugin = const IconDef('assets/icons/general/plugin.svg');
  static IconDef projectPanel = const IconDef(
    'assets/icons/panels/project.svg',
  );
  static IconDef redo = const IconDef('assets/icons/edit/redo.svg');
  static IconDef restoreDown = const IconDef(
    'assets/icons/window/restore-down.svg',
  );
  static IconDef save = const IconDef('assets/icons/edit/save.svg');
  static IconDef solo = const IconDef('assets/icons/mixer/solo.svg');
  static IconDef stop = const IconDef('assets/icons/playback/stop.svg');
  static IconDef undo = const IconDef('assets/icons/edit/undo.svg');
  static IconDef arrowDownThin = const IconDef(
    'assets/icons/arrows/down-small.svg',
  );
  static _ScrollbarIcons scrollbar = _ScrollbarIcons();
  static _TrackIcons track = _TrackIcons();
  static _ToolIcons tools = _ToolIcons();
  static _MainToolbarIcons mainToolbar = _MainToolbarIcons();
}

class _ScrollbarIcons {
  IconDef arrowDown = const IconDef('assets/icons/arrows/down.svg');
  IconDef arrowLeft = const IconDef('assets/icons/arrows/left.svg');
  IconDef arrowRight = const IconDef('assets/icons/arrows/right.svg');
  IconDef arrowUp = const IconDef('assets/icons/arrows/up.svg');
}

class _TrackIcons {
  IconDef add = const IconDef('assets/icons/track/add.svg');
  IconDef audio = const IconDef('assets/icons/track/audio.svg');
  IconDef automationAdd = const IconDef(
    'assets/icons/track/automation-add.svg',
  );
  IconDef automationCollapsed = const IconDef(
    'assets/icons/track/automation-collapsed.svg',
  );
  IconDef automationExpanded = const IconDef(
    'assets/icons/track/automation-expanded.svg',
  );
  IconDef automationFlying = const IconDef(
    'assets/icons/track/automation-flying.svg',
  );
  IconDef folderClosed = const IconDef('assets/icons/track/folder-closed.svg');
  IconDef folderOpen = const IconDef('assets/icons/track/folder-open.svg');
  IconDef instrument = const IconDef('assets/icons/track/instrument.svg');
  IconDef master = const IconDef('assets/icons/track/master.svg');
  IconDef showSendTracks = const IconDef('assets/icons/track/fx.svg');
}

class _ToolIcons {
  IconDef cut = const IconDef('assets/icons/tools/cut.svg');
  IconDef erase = const IconDef('assets/icons/tools/erase.svg');
  IconDef pencil = const IconDef('assets/icons/tools/pencil.svg');
  IconDef select = const IconDef('assets/icons/tools/select.svg');
}

class _MainToolbarIcons {
  IconDef typingKeyboardToPianoKeyboard = const IconDef(
    'assets/icons/playback/piano-keyboard.svg',
  );
}

class SvgIcon extends StatelessWidget {
  final IconDef icon;
  final Color color;
  final double? size;

  const SvgIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      icon.path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
