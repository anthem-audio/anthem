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
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_renderer.dart';

class Menu extends StatefulWidget {
  final AnthemMenuController menuController;
  final MenuDef menuDef;
  final Widget? child;
  late final MenuAlignment menuAlignment;
  final void Function()? onClose;

  Menu({
    super.key,
    required this.menuController,
    this.child,
    required this.menuDef,
    MenuAlignment? alignment,
    this.onClose,
  }) {
    menuAlignment = alignment ?? MenuAlignment.bottomLeft;
  }

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int openMenuID = -1;
  List<Id> openMenus = [];

  @override
  Widget build(BuildContext context) {
    final screenOverlayController = Provider.of<ScreenOverlayController>(
      context,
    );
    widget.menuController.open = ([pos]) =>
        openMenu(screenOverlayController, pos);
    return widget.child ?? const SizedBox();
  }

  void openMenu(
    ScreenOverlayController screenOverlayController,
    Offset? incomingPos,
  ) {
    final contentRenderBox = context.findRenderObject() as RenderBox;
    final pos =
        incomingPos ??
        contentRenderBox.localToGlobal(
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
    final id = getId();
    final projectController = Provider.of<ProjectController>(
      context,
      listen: false,
    );

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
              projectController: projectController,
            ),
          );
        },
        onClose: widget.onClose,
      ),
    );
    openMenus.add(id);
  }

  void closeMenu(ScreenOverlayController screenOverlayController) {
    for (var menu in openMenus) {
      screenOverlayController.remove(menu);
    }

    widget.onClose?.call();
  }
}

class AnthemMenuController {
  late void Function([Offset? pos]) open;
}
