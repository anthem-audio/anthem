/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_renderer.dart';

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
    menuAlignment = alignment ?? MenuAlignment.bottomLeft;
  }

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int openMenuID = -1;
  List<ID> openMenus = [];

  @override
  Widget build(BuildContext context) {
    final screenOverlayCubit = Provider.of<ScreenOverlayController>(context);
    widget.menuController.open = () => openMenu(screenOverlayCubit);
    return widget.child ?? const SizedBox();
  }

  void openMenu(ScreenOverlayController screenOverlayController) {
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pos = contentRenderBox.localToGlobal(
      Offset(
        widget.menuAlignment == MenuAlignment.topLeft ||
                widget.menuAlignment == MenuAlignment.bottomLeft
            ? 0
            : contentRenderBox.size.width,
        widget.menuAlignment == MenuAlignment.topLeft ||
                widget.menuAlignment == MenuAlignment.topRight
            ? 0
            : contentRenderBox.size.height,
      ),
    );
    final id = getID();
    screenOverlayController.add(
      id,
      ScreenOverlayEntry(
        builder: (context, id) {
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: MenuRenderer(
              menu: widget.menuDef,
              id: id,
            ),
          );
        },
      ),
    );
    openMenus.add(id);
  }

  void closeMenu(ScreenOverlayController screenOverlayController) {
    for (var menu in openMenus) {
      screenOverlayController.remove(menu);
    }
  }
}

class MenuController {
  Function? open;
}
