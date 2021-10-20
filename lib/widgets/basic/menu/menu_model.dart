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

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ActiveMenus with ChangeNotifier, DiagnosticableTreeMixin {
  List<MenuInstance> instances = [];

  void mutateMenuInstances(
    void Function(List<MenuInstance> menuInstances) mutator,
  ) {
    mutator(instances);
    notifyListeners();
  }
}

class MenuInstance {
  MenuDef menu;
  double x;
  double y;
  int id;

  MenuInstance({
    required this.menu,
    required this.x,
    required this.y,
    required this.id,
  });
}

class MenuDef {
  List<GenericMenuItem> children;

  MenuDef({this.children = const []});
}

class GenericMenuItem {}

class MenuItem extends GenericMenuItem {
  late String text;
  late MenuDef submenu;

  MenuItem({String? text, MenuDef? submenu}) : super() {
    this.text = text ?? "";
    this.submenu = submenu ?? MenuDef(children: []);
  }
}

class Separator extends GenericMenuItem {
  Separator() : super();
}

int _menuIdGen = 0;

abstract class MenuNotification extends Notification {}

class OpenMenuNotification extends MenuNotification {
  final int id = _menuIdGen++;
  final double x;
  final double y;
  final MenuDef menuDef;

  OpenMenuNotification({
    required this.x,
    required this.y,
    required this.menuDef,
  }) : super();
}

class CloseMenuNotification extends MenuNotification {
  int id;

  CloseMenuNotification({required this.id}) : super();
}

class CloseAllMenusNotification extends MenuNotification {
  CloseAllMenusNotification() : super();
}
