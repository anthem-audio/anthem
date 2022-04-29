/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum MenuAlignment { topLeft, topRight, bottomLeft, bottomRight }

class MenuDef {
  List<GenericMenuItem> children;

  MenuDef({this.children = const []});
}

class GenericMenuItem {}

class MenuItem extends GenericMenuItem {
  late String text;
  late MenuDef submenu;
  VoidCallback? onSelected;

  MenuItem({String? text, MenuDef? submenu, this.onSelected}) : super() {
    this.text = text ?? "";
    this.submenu = submenu ?? MenuDef(children: []);
  }
}

class Separator extends GenericMenuItem {
  Separator() : super();
}
