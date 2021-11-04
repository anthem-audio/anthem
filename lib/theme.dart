/*
  Copyright (C) 2021 Joshua Wade, Budislav Stepanov

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

const white = const Color(0xFFFFFFFF);
const black = const Color(0xFF000000);

class Theme {
  static _Panel panel = _Panel();
  static _Primary primary = _Primary();
  static _Control control = _Control();
  static _Text text = _Text();
  static Color separator = white.withOpacity(0.12);
}

class _Panel {
  Color main = Color.fromARGB(255, 53, 62, 69);
  Color accent = Color.fromARGB(255, 61, 72, 79);
  Color border = Color.fromARGB(255, 41, 49, 54);
}

class _Primary {
  Color main = Color(0xFF07D2D4);
}

class _Control {
  Color hover = white.withOpacity(0.12);
  Color active = white.withOpacity(0.07);
}

class _Text {
  Color main = white.withOpacity(0.7);
}
