/*
  Copyright (C) 2022 Joshua Wade

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
import 'package:flutter_svg/svg.dart';

class IconDef {
  String path;

  IconDef(this.path);
}

class Icons {
  static IconDef arrowDown = IconDef("assets/icons/small/arrow_down_selectbtn.svg");
  static IconDef close = IconDef("assets/icons/small/close.svg");
  static IconDef hamburger = IconDef("assets/icons/misc/hamburgner.svg");
  static IconDef kebab = IconDef("assets/icons/misc.svg");
  static IconDef redo = IconDef("assets/icons/edit/redo.svg");
  static IconDef save = IconDef("assets/icons/edit/save.svg");
  static IconDef undo = IconDef("assets/icons/edit/undo.svg");
}

class SvgIcon extends StatelessWidget {
  final IconDef iconDef;
  final Color color;

  const SvgIcon(this.iconDef, {Key? key, required this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      iconDef.path,
      color: color,
    );
  }
}
