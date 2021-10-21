/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:flutter/widgets.dart';

class Menu extends StatefulWidget {
  final MenuController menuController;
  final MenuDef menuDef;
  final Widget? child;
  late final MenuAlignment menuAlignment;

  Menu({
    Key? key,
    required this.menuController,
    this.child,
    required this.menuDef,
    MenuAlignment? alignment,
  }) : super(key: key) {
    this.menuAlignment = alignment ?? MenuAlignment.TopLeft;
  }

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int openMenuID = -1;

  @override
  Widget build(BuildContext context) {
    widget.menuController.open = openMenu;
    return widget.child ?? SizedBox();
  }

  void openMenu() {
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pos = contentRenderBox.localToGlobal(
      Offset(
        widget.menuAlignment == MenuAlignment.TopLeft ||
                widget.menuAlignment == MenuAlignment.BottomLeft
            ? 0
            : contentRenderBox.size.width,
        widget.menuAlignment == MenuAlignment.TopLeft ||
                widget.menuAlignment == MenuAlignment.TopRight
            ? 0
            : contentRenderBox.size.width,
      ),
    );
    final notification = OpenMenuNotification(
      x: pos.dx,
      y: pos.dy,
      menuDef: widget.menuDef,
    );
    openMenuID = notification.id;
    notification.dispatch(context);
  }

  void closeMenu() {
    CloseMenuNotification(id: openMenuID).dispatch(context);
  }
}

class MenuController {
  Function? open;
}
