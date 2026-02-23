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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/basic/menu/menu_positioning.dart';
import 'package:anthem/widgets/basic/menu/menu_renderer.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:flutter/widgets.dart';

/// Convenience function for opening a context menu.
///
/// Instead of anchoring to a component's render area, as in the case of the
/// [Menu] component, this method takes a window coordinate and opens the menu
/// at that position.
///
/// Returns an [Id] that can be used to close the menu if needed with
/// [closeContextMenu].
Id openContextMenu(Offset globalPosition, MenuDef menu) {
  final menuId = getId();
  final anchorRect = Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0);

  final screenOverlayController = ServiceRegistry.screenOverlayController;
  screenOverlayController.add(
    menuId,
    ScreenOverlayEntry(
      builder: (context, id) {
        return MenuPositioned(
          anchorRect: anchorRect,
          child: MenuRenderer(menu: menu, id: id),
        );
      },
    ),
  );

  return menuId;
}

/// Closes the context menu with the given ID.
///
/// See [openContextMenu] for reference.
void closeContextMenu(Id id) {
  final screenOverlayController = ServiceRegistry.screenOverlayController;
  screenOverlayController.remove(id);
}
