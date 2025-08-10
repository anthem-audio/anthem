/*
  Copyright (C) 2021 - 2025 Joshua Wade

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
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/icon.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_controller.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:anthem/widgets/project/project_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'menu_model.dart';

class _Constants {
  static const double submenuArrowWidth = 8.0;
  static const double padding = 8.0;
  static const double fontSize = 11.0;
  static const double separatorHeight = 13.0;
  static const double menuItemHeight = 25.0;

  static const Duration hoverOpenDuration = Duration(milliseconds: 500);
  static const Duration hoverCloseDuration = Duration(milliseconds: 500);
}

double getMenuItemHeight(GenericMenuItem menuItem) {
  if (menuItem is AnthemMenuItem) return _Constants.menuItemHeight;
  if (menuItem is Separator) return _Constants.separatorHeight;
  return 0;
}

class MenuRenderer extends StatefulWidget {
  final MenuDef menu;
  final Id id;
  final ProjectController projectController;

  const MenuRenderer({
    super.key,
    required this.menu,
    required this.id,
    required this.projectController,
  });

  @override
  State<MenuRenderer> createState() => _MenuRendererState();
}

class _MenuRendererState extends State<MenuRenderer> {
  bool isMouseInside = false;

  int? hintId;

  @override
  Widget build(BuildContext context) {
    final hasSubmenu = widget.menu.children
        .whereType<AnthemMenuItem>()
        .fold<bool>(
          false,
          (previousValue, element) => previousValue || element.submenu != null,
        );

    final widest = widget.menu.children
        .whereType<AnthemMenuItem>()
        .map((child) {
          final labelWidth = measureText(
            text: child.text,
            textStyle: const TextStyle(fontSize: _Constants.fontSize),
            context: context,
          ).width;
          var submenuArrowWidth = hasSubmenu
              ? _Constants.padding +
                    _Constants.submenuArrowWidth +
                    (child.submenu != null ? 50 : 0)
              : 0;
          // The extra 4 pixels here is due to the border from the hover effect,
          // plus something else that I'm not sure about. We need 2px for the hover
          // effect border... I suppose the other 5px are for good luck. Anything
          // less than 7 extra pixels means it will sometimes overflow.
          return (labelWidth + submenuArrowWidth + 7);
        })
        .fold<double>(0, (value, element) => max(value, element));

    final height = widget.menu.children.fold<double>(
      0,
      (value, element) => value + getMenuItemHeight(element),
    );

    return MouseRegion(
      onEnter: (event) {
        setState(() {
          isMouseInside = true;
        });
      },
      onExit: (event) {
        setState(() {
          isMouseInside = false;
        });
        if (hintId != null) {
          HintStore.instance.removeHint(hintId!);
          hintId = null;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AnthemTheme.panel.background,
          border: Border.all(color: AnthemTheme.panel.border),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        width: widest + (_Constants.padding + 1) * 4,
        height: height + (_Constants.padding + 1) * 2,
        child: Padding(
          padding: const EdgeInsets.all(_Constants.padding),
          child: Column(
            children: widget.menu.children
                .map(
                  (child) => MenuItemRenderer(
                    menuItem: child,
                    isMouseInMenu: isMouseInside,
                    projectController: widget.projectController,
                    updateHintId: (id) {
                      if (hintId != null) {
                        HintStore.instance.removeHint(hintId!);
                      }
                      hintId = id;
                    },
                    removeHint: () {
                      if (hintId != null) {
                        HintStore.instance.removeHint(hintId!);
                        hintId = null;
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class MenuItemRenderer extends StatefulWidget {
  final GenericMenuItem menuItem;
  final bool isMouseInMenu;
  final ProjectController projectController;

  final void Function(int) updateHintId;
  final void Function() removeHint;

  const MenuItemRenderer({
    super.key,
    required this.menuItem,
    required this.isMouseInMenu,
    required this.projectController,
    required this.updateHintId,
    required this.removeHint,
  });

  @override
  State<MenuItemRenderer> createState() => _MenuItemRendererState();
}

class _MenuItemRendererState extends State<MenuItemRenderer> {
  bool isHovered = false;
  bool get isSubmenuOpen {
    return submenuKey != null;
  }

  // If there's no open submenu, this is null
  Id? submenuKey;

  // This will be defined if the user has hovered an item with a submenu but
  // the submenu hasn't opened yet
  Timer? hoverTimer;

  // This will be defined if the user has hovered a different item in this
  // menu, but the open submenu hasn't closed yet
  Timer? submenuCloseTimer;

  @override
  void didUpdateWidget(MenuItemRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final screenOverlayController = Provider.of<ScreenOverlayController>(
      context,
    );

    if (!oldWidget.isMouseInMenu &&
        widget.isMouseInMenu &&
        isSubmenuOpen &&
        !isHovered) {
      startSubmenuCloseTimer(screenOverlayController);
    } else if (oldWidget.isMouseInMenu && !widget.isMouseInMenu) {
      cancelSubmenuCloseTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenOverlayController = Provider.of<ScreenOverlayController>(
      context,
    );

    final height = getMenuItemHeight(widget.menuItem);

    if (widget.menuItem is AnthemMenuItem) {
      final item = widget.menuItem as AnthemMenuItem;

      final showHoverState =
          isHovered || (isSubmenuOpen && !widget.isMouseInMenu);

      final textColor = showHoverState
          ? AnthemTheme.primary.main
          : item.disabled
          ? AnthemTheme.text.disabled
          : AnthemTheme.text.main;

      final rowChildren = [
        Text(
          item.text,
          style: TextStyle(color: textColor, fontSize: _Constants.fontSize),
        ),
        const Expanded(child: SizedBox()),
      ];

      if (item.submenu != null) {
        rowChildren.add(const SizedBox(width: _Constants.padding));
        rowChildren.add(
          SizedBox(
            width: _Constants.submenuArrowWidth,
            child: Transform.rotate(
              angle: -pi / 2,
              alignment: Alignment.center,
              child: SvgIcon(icon: Icons.arrowDown, color: textColor),
            ),
          ),
        );
      }

      return MouseRegion(
        onEnter: (e) {
          if (item.disabled) return;

          setState(() {
            isHovered = true;
          });

          if (item.submenu != null && !isSubmenuOpen) {
            startHoverTimer(
              screenOverlayController: screenOverlayController,
              item: item,
            );
          }

          if (item.hint != null) {
            widget.updateHintId(
              HintStore.instance.addHint([HintSection('click', item.hint!)]),
            );
          } else {
            widget.removeHint();
          }

          cancelSubmenuCloseTimer();
        },
        onExit: (e) {
          if (item.disabled) return;

          setState(() {
            isHovered = false;
          });
          cancelHoverTimer();
          startSubmenuCloseTimer(screenOverlayController);
        },
        child: GestureDetector(
          onTap: () {
            if (item.disabled) return;

            item.onSelected?.call();

            if (item.submenu == null) {
              screenOverlayController.clear();
              widget.removeHint();
            } else {
              openSubmenu(
                screenOverlayController: screenOverlayController,
                item: item,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: showHoverState ? AnthemTheme.primary.subtle : null,
              // This adds 2px to the width of the menu
              border: showHoverState
                  ? Border.all(color: AnthemTheme.primary.subtleBorder)
                  : Border.all(color: const Color(0x00000000)),
              borderRadius: BorderRadius.circular(4),
            ),
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _Constants.padding,
              ),
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
          child: Container(color: AnthemTheme.separator),
        ),
      );
    }

    return const SizedBox();
  }

  void openSubmenu({
    required ScreenOverlayController screenOverlayController,
    required AnthemMenuItem item,
  }) {
    if (isSubmenuOpen) return;

    final position = (context.findRenderObject() as RenderBox).localToGlobal(
      const Offset(0, 0),
    );
    final size = context.size!;

    submenuKey = getId();

    screenOverlayController.add(
      submenuKey!,
      ScreenOverlayEntry(
        builder: (screenOverlayContext, id) {
          return Positioned(
            left: position.dx + size.width + _Constants.padding,
            top:
                position.dy -
                _Constants.padding -
                1, // -1 to account for menu border
            child: MenuRenderer(
              id: id,
              menu: item.submenu!,
              projectController: widget.projectController,
            ),
          );
        },
      ),
    );
  }

  void startHoverTimer({
    required ScreenOverlayController screenOverlayController,
    required AnthemMenuItem item,
  }) {
    hoverTimer = Timer(_Constants.hoverOpenDuration, () {
      openSubmenu(screenOverlayController: screenOverlayController, item: item);

      hoverTimer = null;
    });
  }

  void cancelHoverTimer() {
    hoverTimer?.cancel();
    hoverTimer = null;
  }

  void startSubmenuCloseTimer(ScreenOverlayController screenOverlayController) {
    submenuCloseTimer = Timer(_Constants.hoverCloseDuration, () {
      if (submenuKey != null) {
        screenOverlayController.remove(submenuKey!);
        setState(() {
          submenuKey = null;
        });
      }
    });
  }

  void cancelSubmenuCloseTimer() {
    submenuCloseTimer?.cancel();
    submenuCloseTimer = null;
  }
}
