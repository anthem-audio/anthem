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

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_model.dart';

class MenuOverlay extends StatefulWidget {
  final Widget child;

  MenuOverlay({Key? key, required this.child}) : super(key: key);

  @override
  _MenuOverlayState createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  List<MenuInstance> openMenus = [];

  void closeAllMenus() {
    setState(() {
      openMenus = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool Function(MenuNotification) onNotification = (n) {
      print("notif");
      if (n is OpenMenuNotification) {
        setState(() {
          openMenus.add(
            MenuInstance(menu: MenuDef(), x: n.x, y: n.y, id: n.id),
          );
        });
        return true;
      }
      if (n is CloseMenuNotification) {
        setState(() {
          openMenus.removeWhere((element) => element.id == n.id);
        });
        return true;
      }
      if (n is CloseAllMenusNotification) {
        closeAllMenus();
        return true;
      }

      return false;
    };

    return NotificationListener<MenuNotification>(
      onNotification: onNotification,
      child: Stack(children: [
        widget.child,
        IgnorePointer(
          ignoring: openMenus.length == 0,
          child: Stack(
            children: <Widget>[
                  GestureDetector(onTap: () {
                    closeAllMenus();
                  }),
                ] +
                openMenus
                    .map(
                      (menuInstance) => Positioned(
                        left: menuInstance.x,
                        top: menuInstance.y,
                        child: Container(
                          color: Color(0x55FFFFFF),
                          width: 100,
                          height: 100,
                        ),
                      ),
                    )
                    .toList(),
          ),
        )
      ]),
    );
  }
}
