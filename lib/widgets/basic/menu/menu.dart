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

  const Menu({
    Key? key,
    required this.menuController,
    this.child,
    required this.menuDef,
  }) : super(key: key);

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int openMenuID = -1;

  @override
  Widget build(BuildContext context) {
    return widget.child ?? SizedBox();
  }

  void openMenu() {
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pos = contentRenderBox.localToGlobal(Offset(0, 0));
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

  @override
  void initState() {
    widget.menuController.open = () {
      openMenu();
    };
    super.initState();
  }
}

class MenuController {
  Function? open;
}
