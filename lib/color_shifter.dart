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

  AnthemColorShifter(this.hue) {
    const baseDartUiColorNoShift = Color(0xFF28D1AA);
    final baseColorNoShift = baseDartUiColorNoShift.toOkHsl();

    final okBaseColor = baseColorNoShift.withHue(hue / 360);
    main = okBaseColor.toColor();
    subtle = main.withValues(alpha: 0.11);
    subtleBorder = main.withValues(alpha: 0.38);
  }
}
