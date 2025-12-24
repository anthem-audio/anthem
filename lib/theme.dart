/*
  Copyright (C) 2021 - 2025 Joshua Wade, Budislav Stepanov

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

import 'package:anthem/color_shifter.dart';
import 'package:flutter/widgets.dart';

const white = Color(0xFFFFFFFF);
const black = Color(0xFF000000);

class AnthemTheme {
  static final colorShifter = AnthemColorShifter(166);

  static _Panel panel = _Panel();
  static _Primary primary = _Primary(colorShifter);
  static _Control control = _Control();
  static _Text text = _Text();
  static _Grid grid = _Grid();
  static _Overlay overlay = _Overlay();
}

class _Panel {
  Color border = const Color(0xFF2F2F2F);
  Color borderLight = const Color(0xFF5E5E5E);
  Color borderLightActive = const Color(0xFF6A6A6A);
  Color background = const Color(0XFF3F3F3F);
  Color backgroundLight = const Color(0XFF464646);
  Color main = const Color(0XFF4F4F4F);
  Color accent = const Color(0XFF525252);

  Color scrollbar = const Color(0xFF8C8C8C);
  Color scrollbarHover = const Color(0xFFA3A3A3);
  Color scrollbarPress = const Color(0xFF787878);
}

class _Primary {
  final AnthemColorShifter colorShifter;

  _Primary(this.colorShifter);

  Color get main => colorShifter.main;
  Color get subtle => colorShifter.subtle;
  Color get subtleBorder => colorShifter.subtleBorder;
}

class _Control {
  _ByBackgroundType main = _ByBackgroundType(
    dark: const Color(0xFF4F4F4F),
    light: const Color(0xFF585858),
  );
  _ByBackgroundType hover = _ByBackgroundType(
    dark: const Color(0xFF585858),
    light: const Color(0xFF636363),
  );
  Color active = const Color(0xFF25C29D);
  Color activeBackground = const Color(0xFF357869);
  Color border = const Color(0xFF323232);

  Color background = const Color(0xFF3D3D3D);
}

class _Overlay {
  Color background = const Color(0xFF3D3D3D);
  Color border = const Color(0xFF636363);
}

const _textMain = Color(0xFFCFCFCF);

class _Text {
  Color main = _textMain;
  Color disabled = _textMain.withAlpha(125);
  Color accent = const Color(0xFFE6E6E6);
}

class _ByBackgroundType {
  Color dark;
  Color light;

  _ByBackgroundType({required this.dark, required this.light});
}

// For grid lines in editors
class _Grid {
  Color minor = const Color(0xFF3E3E3E);
  Color major = const Color(0xFF2E2E2E);
  Color accent = const Color(0xFF1A1A1A);
  Color backgroundLight = const Color(0xFF494949);
  Color backgroundDark = const Color(0xFF434343);
  Color shaded = const Color(0x11000000);
}
