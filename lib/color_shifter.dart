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

import 'dart:ui';

import 'package:okcolor/models/extensions.dart';

/// Handles color shifting for Anthem, based on the Oklab color space.
///
/// This class is responsible for producing the primary color in the UI along
/// with all variations. It also produces color variations for colored items,
/// such as colored channels, tracks, and clips.
class AnthemColorShifter {
  int hue;

  late final Color main;
  late final Color subtle;
  late final Color subtleBorder;

  // For piano roll
  late final Color noteBase;
  late final Color noteHovered;
  late final Color notePressed;
  late final Color noteSelectedBorder;
  late final Color noteSelected;

  AnthemColorShifter(this.hue) {
    const baseDartUiColorNoShift = Color(0xFF28D1AA);
    final baseColorNoShift = baseDartUiColorNoShift.toOkHsl();

    final okBaseColor = baseColorNoShift.withHue(hue / 360);
    main = okBaseColor.toColor();
    subtle = main.withValues(alpha: 0.11);
    subtleBorder = main.withValues(alpha: 0.38);

    final okNoteBase = okBaseColor.darker(0.33).desaturate(0.17);
    final okNoteHovered = okNoteBase.lighter(0.2);
    final okNotePressed = okNoteBase.darker(0.2);
    final okNoteSelectedBorder = okNoteBase.lighter(0.35).saturate(0.1);
    final okNoteSelected = okNoteBase.darker(0.15).desaturate(0.1);

    noteBase = okNoteBase.toColor();
    noteHovered = okNoteHovered.toColor();
    notePressed = okNotePressed.toColor();
    noteSelectedBorder = okNoteSelectedBorder.toColor();
    noteSelected = okNoteSelected.toColor();
  }
}
