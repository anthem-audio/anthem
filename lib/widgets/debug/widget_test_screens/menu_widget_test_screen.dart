/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/menu/menu.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:flutter/widgets.dart';

class MenuWidgetTestScreen extends StatefulWidget {
  const MenuWidgetTestScreen({super.key});

  @override
  State<MenuWidgetTestScreen> createState() => _MenuWidgetTestScreenState();
}

class _MenuWidgetTestScreenState extends State<MenuWidgetTestScreen> {
  final fileMenuController = AnthemMenuController();
  final editMenuController = AnthemMenuController();
  final helpMenuController = AnthemMenuController();

  late final menuControllerGroup = AnthemMenuControllerGroup([
    fileMenuController,
    editMenuController,
    helpMenuController,
  ]);

  bool menuOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (menuOpened) return;
    menuOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fileMenuController.open();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Top-level menu group',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Menu(
              menuController: fileMenuController,
              menuControllerGroup: menuControllerGroup,
              menuDef: MenuDef(
                children: [
                  AnthemMenuItem(text: 'New project', shortcutLabel: 'Ctrl+N'),
                  AnthemMenuItem(
                    text: 'Open project...',
                    shortcutLabel: 'Ctrl+O',
                  ),
                  Separator(),
                  AnthemMenuItem(
                    text: 'Export',
                    submenu: MenuDef(
                      children: [
                        AnthemMenuItem(text: 'Audio file...'),
                        AnthemMenuItem(text: 'Stems...'),
                      ],
                    ),
                  ),
                  AnthemMenuItem(text: 'Unavailable action', disabled: true),
                ],
              ),
              child: Button(
                width: 72,
                height: 28,
                text: 'File',
                onPress: fileMenuController.toggle,
              ),
            ),
            Menu(
              menuController: editMenuController,
              menuControllerGroup: menuControllerGroup,
              menuDef: MenuDef(
                children: [
                  AnthemMenuItem(text: 'Undo', shortcutLabel: 'Ctrl+Z'),
                  AnthemMenuItem(text: 'Redo', shortcutLabel: 'Ctrl+Shift+Z'),
                ],
              ),
              child: Button(
                width: 72,
                height: 28,
                text: 'Edit',
                onPress: editMenuController.toggle,
              ),
            ),
            Menu(
              menuController: helpMenuController,
              menuControllerGroup: menuControllerGroup,
              menuDef: MenuDef(children: [AnthemMenuItem(text: 'About...')]),
              child: Button(
                width: 72,
                height: 28,
                text: 'Help',
                onPress: helpMenuController.toggle,
              ),
            ),
          ],
        ),
        Text(
          'Hovering File, Edit, or Help switches menus while one is open. '
          'Hovering does nothing while the group is closed.',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ],
    );
  }
}
