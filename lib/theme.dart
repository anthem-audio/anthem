/*
  Copyright (C) 2021 - 2022 Joshua Wade, Budislav Stepanov

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

import 'package:flutter/widgets.dart';

const white = Color(0xFFFFFFFF);
const black = Color(0xFF000000);

class Theme {
  static _Panel panel = _Panel();
  static _Primary primary = _Primary();
  static _Control control = _Control();
  static _Text text = _Text();
  static Color separator = white.withOpacity(0.12);
  static _Grid grid = _Grid();
}

class _Panel {
  Color main = const Color(0xFF353E45);
  Color accent = const Color(0xFF3D484F);
  Color accentDark = const Color(0xFF313A40);
  Color border = const Color(0xFF293136);
}

class _Primary {
  Color main = const Color(0xFF25C29D);
  Color subtle = const Color(0xFF20A888).withOpacity(0.11);
  Color subtleBorder = const Color(0xFF25C29D).withOpacity(0.38);
}

class _Control {
  _ByBackgroundType main = _ByBackgroundType(
    dark: const Color(0xFF414C54),
    light: const Color(0xFF4C5A63),
  );
  _ByBackgroundType hover = _ByBackgroundType(
    dark: const Color(0xFF4B5861),
    light: const Color(0xFF505F69),
  );
  Color active = const Color(0xFF25C29D);
  Color border = const Color(0xFF293136);
}

class _Text {
  Color main = const Color(0xFF9DB9CC);
}

class _ByBackgroundType {
  Color dark;
  Color light;

  _ByBackgroundType({required this.dark, required this.light});
}

// For grid lines in editors
class _Grid {
  Color major = const Color(0xFF242A2E);
  Color minor = const Color(0xFF2B3237);
  Color accent = const Color(0xFF0F1113);
  Color backgroundLight = const Color(0xFF394349);
  Color backgroundDark = const Color(0xFF333D43);
  Color shaded = const Color(0x11000000);
}
