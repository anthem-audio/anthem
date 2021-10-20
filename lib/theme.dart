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

import 'package:flutter/cupertino.dart';

class Theme {
  static _Panel panel = _Panel();
  static _Primary primary = _Primary();
  static Color separator = Color(0xFFFFFFFF).withOpacity(0.12);
}

class _Panel {
  Color light = Color(0xFFFFFFFF).withOpacity(0.03);
  Color main = Color(0xFFFFFFFF).withOpacity(0.07);
  Color accent = Color(0xFFFFFFFF).withOpacity(0.12);
}

class _Primary {
  Color main = Color(0xFF07D2D4);
}