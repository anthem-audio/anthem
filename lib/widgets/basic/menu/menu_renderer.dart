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

import 'dart:async';
import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/measure_text.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_model.dart';

class _Constants {
  static const double submenuArrowWidth = 8.0;
  static const double padding = 12.0;
  static const double fontSize = 11.0;
  static const double separatorHeight = 13.0;
  static const double menuItemHeight = 25.0;

  static const Duration hoverOpenDuration = Duration(milliseconds: 500);
  static const Duration hoverCloseDuration = Duration(milliseconds: 500);
}

double getMenuItemHeight(GenericMenuItem menuItem) {
  if (menuItem is MenuItem) return _Constants.menuItemHeight;
  if (menuItem is Separator) return _Constants.separatorHeight;
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
    final hasSubmenu = menu.children.whereType<MenuItem>().fold<bool>(false,
        (previousValue, element) => previousValue || element.submenu != null);

    final widest = menu.children.whereType<MenuItem>().map((child) {
      final labelWidth = measureText(
        text: child.text,
        textStyle: const TextStyle(fontSize: _Constants.fontSize),
        context: context,
      ).width;
      var submenuArrowWidth =
          hasSubmenu ? _Constants.padding + _Constants.submenuArrowWidth : 0;
      // The 2px extra here is due to the border from the hover effect
      return labelWidth + submenuArrowWidth + 2;
    }).fold<double>(0, (value, element) => max(value, element));

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
      width: widest + (_Constants.padding + 1) * 2,
      height: height + (_Constants.padding + 1) * 2,
      child: Padding(
        padding: const EdgeInsets.only(
            top: _Constants.padding, bottom: _Constants.padding),
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
  bool submenuOpen = false;

  // If there's no open submenu, this is null
  ID? submenuKey;

  // This will be defined if the user has hovered an item with a submenu but
  // the submenu hasn't opened yet
  Timer? hoverTimer;

  @override
  Widget build(BuildContext context) {
    final screenOverlayCubit = Provider.of<ScreenOverlayCubit>(context);

    final height = getMenuItemHeight(widget.menuItem);

    if (widget.menuItem is MenuItem) {
      final item = widget.menuItem as MenuItem;

      final rowChildren = [
        Text(
          item.text,
          style: TextStyle(
            color: Theme.text.main,
            fontSize: _Constants.fontSize,
          ),
        ),
        const Expanded(child: SizedBox()),
      ];

      if (item.submenu != null) {
        rowChildren.add(const SizedBox(width: _Constants.padding));
        rowChildren.add(SizedBox(
          width: _Constants.submenuArrowWidth,
          child: Transform.rotate(
            angle: -pi / 2,
            alignment: Alignment.center,
            child: SvgIcon(
              icon: Icons.arrowDown,
              color: Theme.text.main,
            ),
          ),
        ));
      }

      return MouseRegion(
        onEnter: (e) {
          setState(() {
            hovered = true;
          });
          if (item.submenu != null && !submenuOpen) {
            hoverTimer = Timer(_Constants.hoverOpenDuration, () {
              openSubmenu(
                context: context,
                screenOverlayCubit: screenOverlayCubit,
                item: item,
              );

              hoverTimer = null;
            });
          }
        },
        onExit: (e) {
          setState(() {
            hovered = false;
          });
          hoverTimer?.cancel();
        },
        child: GestureDetector(
          onTap: () {
            item.onSelected?.call();
            if (item.submenu == null) {
              screenOverlayCubit.clear();
            } else {
              openSubmenu(
                context: context,
                screenOverlayCubit: screenOverlayCubit,
                item: item,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: hovered || submenuOpen ? Theme.primary.subtle : null,
              // This adds 2px to the width of the menu
              border: hovered || submenuOpen
                  ? Border.all(color: Theme.primary.subtleBorder)
                  : Border.all(color: const Color(0x00000000)),
              borderRadius: BorderRadius.circular(4),
            ),
            height: height,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: _Constants.padding),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
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
            horizontal: _Constants.padding,
            vertical: (_Constants.separatorHeight / 2).floor().toDouble(),
          ),
          child: Container(
            color: Theme.separator,
          ),
        ),
      );
    }

    return const SizedBox();
  }

  void openSubmenu({
    required BuildContext context,
    required ScreenOverlayCubit screenOverlayCubit,
    required MenuItem item,
  }) {
    final position = (context.findRenderObject() as RenderBox).localToGlobal(
      const Offset(0, 0),
    );
    final size = context.size!;

    submenuKey = getID();

    screenOverlayCubit.add(submenuKey!, ScreenOverlayEntry(
      builder: (screenOverlayContext) {
        return Positioned(
          left: position.dx + size.width,
          top: position.dy -
              _Constants.padding -
              1, // -1 to account for menu border
          child: MenuRenderer(id: submenuKey!, menu: item.submenu!),
        );
      },
    ));

    setState(() {
      submenuOpen = true;
    });
  }
}
