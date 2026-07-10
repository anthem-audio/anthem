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
  final menuController = AnthemMenuController();
  bool menuOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (menuOpened) return;
    menuOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      menuController.open();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(
          'Popup menu',
          style: TextStyle(color: AnthemTheme.text.accent, fontSize: 12),
        ),
        Menu(
          menuController: menuController,
          menuDef: MenuDef(
            children: [
              AnthemMenuItem(text: 'New project', shortcutLabel: 'Ctrl+N'),
              AnthemMenuItem(text: 'Open project...', shortcutLabel: 'Ctrl+O'),
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
            width: 140,
            height: 28,
            text: 'Toggle menu',
            showMenuIndicator: true,
            onPress: menuController.toggle,
          ),
        ),
        Text(
          'Click elsewhere to dismiss the menu and activate the control '
          'under the same click.',
          style: TextStyle(color: AnthemTheme.text.main, fontSize: 12),
        ),
      ],
    );
  }
}
