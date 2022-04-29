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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/measure_text.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';
import 'menu_model.dart';

const menuItemHeight = 25.0;
const separatorHeight = 13.0;
const padding = 12.0;

double getMenuItemHeight(GenericMenuItem menuItem) {
  if (menuItem is MenuItem) return menuItemHeight;
  if (menuItem is Separator) return separatorHeight;
  return 0;
}

class MenuRenderer extends StatelessWidget {
  final MenuDef menu;
  final ID id;

  const MenuRenderer({
    Key? key,
    required this.menu,
    required this.id,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widest = menu.children
        .whereType<MenuItem>()
        .map((child) => measureText(
              text: child.text,
              textStyle: const TextStyle(),
              context: context,
            ).width)
        .fold<double>(0, (value, element) => max(value, element));

    final height = menu.children.fold<double>(
        0, (value, element) => value + getMenuItemHeight(element));

    return Container(
      decoration: BoxDecoration(
        color: Theme.panel.accentDark,
        border: Border.all(color: Theme.panel.border),
        borderRadius: const BorderRadius.all(
          Radius.circular(4),
        ),
      ),
      width: widest + (padding + 1) * 2,
      height: height + (padding + 1) * 2,
      child: Padding(
        padding: const EdgeInsets.only(top: padding, bottom: padding),
        child: Column(
          children: menu.children
              .map((child) => MenuItemRenderer(menuItem: child))
              .toList(),
        ),
      ),
    );
  }
}

class MenuItemRenderer extends StatefulWidget {
  final GenericMenuItem menuItem;

  const MenuItemRenderer({Key? key, required this.menuItem}) : super(key: key);

  @override
  State<MenuItemRenderer> createState() => _MenuItemRendererState();
}

class _MenuItemRendererState extends State<MenuItemRenderer> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final screenOverlayCubit = Provider.of<ScreenOverlayCubit>(context);

    final height = getMenuItemHeight(widget.menuItem);

    if (widget.menuItem is MenuItem) {
      final item = widget.menuItem as MenuItem;
      return MouseRegion(
        onEnter: (e) {
          setState(() {
            hovered = true;
          });
        },
        onExit: (e) {
          setState(() {
            hovered = false;
          });
        },
        child: GestureDetector(
          onTap: () {
            item.onSelected?.call();
            // CloseAllMenusNotification().dispatch(context);
            screenOverlayCubit.clear();
          },
          child: Container(
            color: hovered ? Theme.primary.main : null,
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: padding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item.text),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.menuItem is Separator) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: (separatorHeight / 2).floor().toDouble(),
          ),
          child: Container(
            color: Theme.separator,
          ),
        ),
      );
    }

    return const SizedBox();
  }
}
